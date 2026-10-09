#!/usr/bin/env python3
"""Assemble a verified third-party distribution packet for an FFmpeg artifact."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tempfile
from typing import Any, Iterable
from urllib.parse import urlsplit


class PacketError(Exception):
    pass


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Verify exact third-party sources and assemble attribution, accompanying-source, "
            "and relink material (static archives, or the runtime framework and how to replace it) "
            "under <artifact-root>/distribution."
        )
    )
    parser.add_argument("--artifact-root", required=True, type=Path)
    parser.add_argument("--provenance", required=True, type=Path)
    parser.add_argument("--source-archive-root", required=True, type=Path)
    return parser.parse_args()


def read_json_object(path: Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise PacketError(f"{label} is not a regular file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise PacketError(f"cannot read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise PacketError(f"{label} must contain a JSON object: {path}")
    return value


def nonempty_text(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise PacketError(f"{field} must be a nonempty string")
    result = value.strip()
    if "\n" in result or "\r" in result:
        raise PacketError(f"{field} must be a single line")
    return result


def normalized_component(value: str) -> str:
    result = re.sub(r"[^a-z0-9]", "", value.lower())
    if result.startswith("lib") and len(result) > 3:
        result = result[3:]
    return result


def ordered_unique(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_artifact_file(artifact_root: Path, relative_path: str, label: str) -> Path:
    pure_path = PurePosixPath(relative_path)
    if pure_path.is_absolute() or not pure_path.parts or ".." in pure_path.parts:
        raise PacketError(f"{label} must stay inside the artifact root: {relative_path}")
    candidate = artifact_root.joinpath(*pure_path.parts)
    resolved = candidate.resolve()
    if artifact_root != resolved and artifact_root not in resolved.parents:
        raise PacketError(f"{label} escapes the artifact root: {relative_path}")
    if candidate.is_symlink() or not candidate.is_file() or candidate.stat().st_size <= 0:
        raise PacketError(f"{label} is missing, empty, or not a regular file: {relative_path}")
    return candidate


def safe_artifact_directory(artifact_root: Path, relative_path: str, label: str) -> Path:
    pure_path = PurePosixPath(relative_path)
    if pure_path.is_absolute() or not pure_path.parts or ".." in pure_path.parts:
        raise PacketError(f"{label} must stay inside the artifact root: {relative_path}")
    candidate = artifact_root.joinpath(*pure_path.parts)
    resolved = candidate.resolve()
    if artifact_root != resolved and artifact_root not in resolved.parents:
        raise PacketError(f"{label} escapes the artifact root: {relative_path}")
    if candidate.is_symlink() or not candidate.is_dir():
        raise PacketError(f"{label} is not a regular directory: {relative_path}")
    return candidate


def manifest_path(artifact_root: Path) -> Path:
    for name in (
        "nsurator-player-core-ffmpeg-apple-manifest.json",
        "nsurator-player-core-ffmpeg-visionos-manifest.json",
    ):
        candidate = artifact_root / name
        if candidate.is_file() and not candidate.is_symlink():
            return candidate
    raise PacketError(f"artifact manifest is missing under: {artifact_root}")


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def release_identifier(value: Any, field: str) -> str:
    result = nonempty_text(value, field)
    if "/" in result or "\\" in result:
        raise PacketError(f"{field} must not contain a local filesystem path")
    return result


def contains_personal_filesystem_path(value: str) -> bool:
    return bool(
        re.search(r"(?:^|[= '\"])(?:/Users/|/home/|[A-Za-z]:[\\/])", value)
    )


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value.rstrip() + "\n", encoding="utf-8")


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def distribution_support_entries(distribution_root: Path) -> list[dict[str, str]]:
    kind_by_directory = {
        "attribution": "attribution",
        "source-offer": "sourceOffer",
        "relink-instructions": "relinkInstructions",
        "relink-materials-manifest": "relinkMaterialsManifest",
    }
    entries: list[dict[str, str]] = []
    for path in sorted(distribution_root.rglob("*"), key=lambda item: item.as_posix().lower()):
        if path.is_symlink():
            raise PacketError(f"generated distribution file must not be a symlink: {path}")
        if not path.is_file():
            continue
        relative_path = path.relative_to(distribution_root)
        if len(relative_path.parts) < 2 or relative_path.parts[0] not in kind_by_directory:
            raise PacketError(f"generated distribution file has an unsupported location: {relative_path}")
        entries.append({
            "kind": kind_by_directory[relative_path.parts[0]],
            "relativePath": f"distribution/{relative_path.as_posix()}",
        })
    return entries


def update_artifact_manifests(
    artifact_root: Path,
    support_entries: list[dict[str, str]],
) -> None:
    prepared: list[tuple[Path, Path, bytes]] = []
    for name in (
        "nsurator-player-core-ffmpeg-apple-manifest.json",
        "nsurator-player-core-ffmpeg-visionos-manifest.json",
    ):
        path = artifact_root / name
        if not path.exists():
            continue
        manifest = read_json_object(path, "artifact manifest")
        manifest["distributionSupportFiles"] = support_entries
        temporary_path = artifact_root / f".{name}.release-packet-{os.getpid()}.tmp"
        if temporary_path.exists():
            raise PacketError(f"temporary manifest path already exists: {temporary_path}")
        original_data = path.read_bytes()
        temporary_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        prepared.append((temporary_path, path, original_data))
    if not prepared:
        raise PacketError("artifact has no manifest to update")

    replaced: list[tuple[Path, bytes]] = []
    try:
        for temporary_path, path, original_data in prepared:
            os.replace(temporary_path, path)
            replaced.append((path, original_data))
    except OSError:
        for path, original_data in replaced:
            restore_path = artifact_root / f".{path.name}.release-packet-restore-{os.getpid()}.tmp"
            restore_path.write_bytes(original_data)
            os.replace(restore_path, path)
        raise
    finally:
        for temporary_path, _, _ in prepared:
            if temporary_path.exists():
                temporary_path.unlink()


def collect_static_libraries(
    artifact_root: Path,
    manifest: dict[str, Any],
) -> list[dict[str, str]]:
    relative_roots = [manifest.get("installRootRelativePath") or "install"]
    dependency_root = manifest.get("dependencyRootRelativePath")
    if dependency_root or manifest.get("dependencyRoot"):
        relative_roots.append(dependency_root or "dependencies")

    libraries: list[dict[str, str]] = []
    for relative_root in ordered_unique(relative_roots):
        root = safe_artifact_directory(artifact_root, relative_root, "artifact library root")
        for path in sorted(root.rglob("*.a"), key=lambda item: item.as_posix().lower()):
            if path.is_symlink() or not path.is_file() or path.stat().st_size <= 0:
                raise PacketError(f"static library is missing, empty, or a symlink: {path}")
            libraries.append({
                "relativePath": path.relative_to(artifact_root).as_posix(),
                "sha256": sha256(path),
            })
    return libraries


def collect_runtime_frameworks(
    artifact_root: Path,
    manifest: dict[str, Any],
) -> list[dict[str, Any]]:
    frameworks: list[dict[str, Any]] = []
    for slice_manifest in manifest.get("slices", []) or []:
        if not isinstance(slice_manifest, dict):
            continue
        slice_name = nonempty_text(slice_manifest.get("name"), "slices[].name")
        relative_path = nonempty_text(
            slice_manifest.get("runtimeFrameworkRelativePath"),
            f"slices[{slice_name}].runtimeFrameworkRelativePath",
        )
        framework_root = safe_artifact_directory(artifact_root, relative_path, "runtime framework")
        name = nonempty_text(
            slice_manifest.get("runtimeFrameworkName"), f"slices[{slice_name}].runtimeFrameworkName"
        )
        binary_relative_path = f"{relative_path}/Versions/A/{name}"
        binary = safe_artifact_file(artifact_root, binary_relative_path, "runtime framework binary")
        expected_sha256 = nonempty_text(
            slice_manifest.get("runtimeFrameworkBinarySHA256"),
            f"slices[{slice_name}].runtimeFrameworkBinarySHA256",
        )
        actual_sha256 = sha256(binary)
        if actual_sha256 != expected_sha256:
            raise PacketError(
                f"runtime framework checksum mismatch for {slice_name}: "
                f"expected {expected_sha256}, got {actual_sha256}"
            )
        record_path = framework_root.parent / "FRAMEWORK-RECORD.json"
        record = read_json_object(record_path, "runtime framework record")
        if record.get("binarySHA256") != actual_sha256:
            raise PacketError(f"runtime framework record does not describe the packaged binary: {record_path}")
        for command_word in record.get("linkCommand", []) or []:
            if isinstance(command_word, str) and contains_personal_filesystem_path(command_word):
                raise PacketError("runtime framework link command contains a personal filesystem path")
        frameworks.append({
            "slice": slice_name,
            "name": name,
            "relativePath": relative_path,
            "binaryRelativePath": binary_relative_path,
            "installName": nonempty_text(
                slice_manifest.get("runtimeFrameworkInstallName"),
                f"slices[{slice_name}].runtimeFrameworkInstallName",
            ),
            "binarySHA256": actual_sha256,
            "uuid": nonempty_text(
                slice_manifest.get("runtimeFrameworkUUID"), f"slices[{slice_name}].runtimeFrameworkUUID"
            ),
            "recordPath": record_path,
        })
    if not frameworks:
        raise PacketError("framework artifact declares no runtime framework")
    return frameworks


def assemble_packet(
    artifact_root: Path,
    provenance_path: Path,
    source_archive_root: Path,
) -> tuple[int, int, int]:
    if artifact_root.is_symlink():
        raise PacketError(f"artifact root must not be a symlink: {artifact_root}")
    if provenance_path.is_symlink():
        raise PacketError(f"artifact provenance must not be a symlink: {provenance_path}")
    if source_archive_root.is_symlink():
        raise PacketError(f"source archive root must not be a symlink: {source_archive_root}")
    artifact_root = artifact_root.resolve()
    provenance_path = provenance_path.resolve()
    source_archive_root = source_archive_root.resolve()
    if not artifact_root.is_dir():
        raise PacketError(f"artifact root is not a regular directory: {artifact_root}")
    if not source_archive_root.is_dir():
        raise PacketError(f"source archive root is not a regular directory: {source_archive_root}")

    artifact_manifest_path = manifest_path(artifact_root)
    manifest = read_json_object(artifact_manifest_path, "artifact manifest")
    provenance = read_json_object(provenance_path, "artifact provenance")

    configure_flags: list[str] = []
    runtime_libraries: list[str] = []
    for owner in [manifest] + [
        value for value in manifest.get("slices", []) if isinstance(value, dict)
    ]:
        for value in owner.get("requiredConfigureFlags", []) or []:
            if isinstance(value, str) and value.strip():
                configure_flags.append(value.strip())
        for value in owner.get("requiredRuntimeLibraries", []) or []:
            if isinstance(value, str) and value.strip():
                runtime_libraries.append(value.strip())
    configure_flags = ordered_unique(configure_flags)
    runtime_libraries = ordered_unique(runtime_libraries)
    if "--enable-nonfree" in configure_flags:
        raise PacketError("--enable-nonfree artifacts cannot receive a redistributable release packet")

    license_entries = manifest.get("thirdPartyLicenseFiles")
    if not isinstance(license_entries, list) or not license_entries:
        raise PacketError("artifact manifest has no declared third-party license files")
    license_paths_by_component: dict[str, list[str]] = {}
    display_names: dict[str, str] = {}
    for index, entry in enumerate(license_entries):
        if not isinstance(entry, dict):
            raise PacketError(f"thirdPartyLicenseFiles[{index}] must be an object")
        component = nonempty_text(entry.get("component"), f"thirdPartyLicenseFiles[{index}].component")
        relative_path = nonempty_text(
            entry.get("relativePath"), f"thirdPartyLicenseFiles[{index}].relativePath"
        )
        safe_artifact_file(artifact_root, relative_path, "declared license file")
        normalized = normalized_component(component)
        if not normalized:
            raise PacketError(f"cannot normalize license component: {component}")
        display_names.setdefault(normalized, component)
        license_paths_by_component.setdefault(normalized, []).append(relative_path)

    provenance_sources = provenance.get("sources")
    if not isinstance(provenance_sources, dict) or not provenance_sources:
        raise PacketError("artifact provenance has no sources object")
    sources: dict[str, dict[str, str]] = {}
    source_archives: list[dict[str, str]] = []
    for component, raw_metadata in provenance_sources.items():
        component_name = nonempty_text(component, "provenance source component")
        if not isinstance(raw_metadata, dict):
            raise PacketError(f"provenance source must be an object: {component_name}")
        normalized = normalized_component(component_name)
        if not normalized or normalized in sources:
            raise PacketError(f"duplicate or invalid provenance source component: {component_name}")
        version = nonempty_text(raw_metadata.get("version"), f"sources.{component_name}.version")
        archive_name = nonempty_text(
            raw_metadata.get("archiveName"), f"sources.{component_name}.archiveName"
        )
        if Path(archive_name).name != archive_name:
            raise PacketError(f"source archiveName must be a filename: {archive_name}")
        source_url = nonempty_text(raw_metadata.get("url"), f"sources.{component_name}.url")
        parsed_url = urlsplit(source_url)
        if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
            raise PacketError(f"source URL must be HTTP(S): {source_url}")
        if parsed_url.username or parsed_url.password or parsed_url.query or parsed_url.fragment:
            raise PacketError(f"source URL must not embed credentials, query data, or fragments: {source_url}")
        expected_sha256 = nonempty_text(
            raw_metadata.get("sha256"), f"sources.{component_name}.sha256"
        ).lower()
        if re.fullmatch(r"[0-9a-f]{64}", expected_sha256) is None:
            raise PacketError(f"source sha256 is invalid for: {component_name}")
        archive_path = source_archive_root / archive_name
        if archive_path.is_symlink() or not archive_path.is_file():
            raise PacketError(f"source archive is missing or not a regular file: {archive_path}")
        actual_sha256 = sha256(archive_path)
        if actual_sha256 != expected_sha256:
            raise PacketError(
                f"source archive checksum mismatch for {archive_name}: "
                f"expected {expected_sha256}, got {actual_sha256}"
            )
        display_names.setdefault(normalized, component_name)
        sources[normalized] = {
            "component": component_name,
            "version": version,
            "archiveName": archive_name,
            "url": source_url,
            "sha256": actual_sha256,
            "sourcePath": str(archive_path),
        }

    required_components = ordered_unique(
        ["ffmpeg"] + [normalized_component(value) for value in runtime_libraries]
    )
    for component in required_components:
        if component not in sources:
            raise PacketError(f"artifact provenance is missing required source: {component}")
        if component not in license_paths_by_component:
            raise PacketError(f"artifact licenses are missing required component: {component}")
    for component in sources:
        if component not in license_paths_by_component:
            raise PacketError(f"provenance source has no declared license document: {component}")

    static_libraries = collect_static_libraries(artifact_root, manifest)
    link_mode = str(manifest.get("swiftpmLinkMode") or "").strip().lower()
    if link_mode not in {"search", "static", "framework"}:
        raise PacketError("artifact manifest must declare swiftpmLinkMode as search, static, or framework")
    if link_mode in {"static", "framework"} and not static_libraries:
        raise PacketError(f"{link_mode} artifact contains no static libraries")
    runtime_frameworks = (
        collect_runtime_frameworks(artifact_root, manifest) if link_mode == "framework" else []
    )

    stage = Path(tempfile.mkdtemp(prefix=".distribution-stage-", dir=artifact_root))
    output_root = artifact_root / "distribution"
    backup_root: Path | None = None
    try:
        for component in sorted(sources):
            metadata = sources[component]
            destination = stage / "source-offer" / "sources" / metadata["archiveName"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(metadata["sourcePath"], destination)
            source_archives.append({
                "component": display_names[component],
                "version": metadata["version"],
                "relativePath": f"distribution/source-offer/sources/{metadata['archiveName']}",
                "upstreamURL": metadata["url"],
                "sha256": metadata["sha256"],
            })

        notice_lines = [
            "# Third-Party Notices",
            "",
            "This artifact contains the third-party components below. Include this notice and the",
            "referenced exact license texts in the product's About, acknowledgements, or EULA flow.",
            "This packet records build inputs; it is not legal certification for a downstream app.",
            "",
            "| Component | Version | Source archive | License documents |",
            "| --- | --- | --- | --- |",
        ]
        for component in sorted(sources):
            metadata = sources[component]
            license_links = ", ".join(
                f"[`{Path(path).name}`](../../{path})"
                for path in sorted(license_paths_by_component[component])
            )
            notice_lines.append(
                f"| {markdown_cell(display_names[component])} | "
                f"{markdown_cell(metadata['version'])} | "
                f"`{markdown_cell(metadata['archiveName'])}` | {license_links} |"
            )
        notice_lines.extend([
            "",
            f"SwiftPM link mode: `{link_mode}`.",
            "",
            "Required FFmpeg configure flags:",
            "",
        ])
        notice_lines.extend(f"- `{flag}`" for flag in configure_flags)
        write_text(stage / "attribution" / "THIRD-PARTY-NOTICES.md", "\n".join(notice_lines))

        source_lines = [
            "# Accompanying Third-Party Source",
            "",
            "The exact source archives recorded for this binary artifact accompany it in `sources/`.",
            "Their SHA-256 values were verified before this packet was generated. Preserve this",
            "directory with redistributed copies, or provide an equivalent compliant source channel",
            "after review of the exact licenses and distribution terms.",
            "",
            "| Component | Version | Archive | SHA-256 | Upstream URL |",
            "| --- | --- | --- | --- | --- |",
        ]
        for entry in source_archives:
            source_lines.append(
                f"| {markdown_cell(entry['component'])} | {markdown_cell(entry['version'])} | "
                f"[`{markdown_cell(Path(entry['relativePath']).name)}`](sources/{Path(entry['relativePath']).name}) | "
                f"`{entry['sha256']}` | `{markdown_cell(entry['upstreamURL'])}` |"
            )
        write_text(stage / "source-offer" / "SOURCE-CODE.md", "\n".join(source_lines))
        sanitized_provenance: dict[str, Any] = {
            "schemaVersion": provenance.get("schemaVersion", 1),
            "sources": {},
        }
        for field in (
            "artifactVersion",
            "packageRevision",
            "platform",
            "architecture",
            "sliceName",
            "minimumMacOSVersion",
            "linkProfile",
            "swiftpmLinkMode",
            "networkProtocolsEnabled",
            "requiredRuntimeLibraries",
        ):
            value = provenance.get(field)
            if isinstance(value, str):
                sanitized_provenance[field] = release_identifier(value, f"provenance.{field}")
            elif isinstance(value, (int, bool)):
                sanitized_provenance[field] = value
            elif isinstance(value, list) and all(isinstance(item, str) for item in value):
                sanitized_provenance[field] = [
                    release_identifier(item, f"provenance.{field}") for item in value
                ]
        sanitized_sources = sanitized_provenance["sources"]
        assert isinstance(sanitized_sources, dict)
        for component in sorted(sources):
            metadata = sources[component]
            sanitized_sources[metadata["component"]] = {
                "archiveName": metadata["archiveName"],
                "sha256": metadata["sha256"],
                "url": metadata["url"],
                "version": metadata["version"],
            }
        write_json(stage / "source-offer" / "SOURCE-PROVENANCE.json", sanitized_provenance)

        if link_mode == "framework":
            relink_lines = [
                "# Replacing the Runtime Framework",
                "",
                "This artifact links FFmpeg, libbluray (with libudfread), and dav1d dynamically. The",
                "consuming app loads them from one framework in its bundle:",
                "",
            ]
            for framework in runtime_frameworks:
                relink_lines.append(
                    f"- `{framework['slice']}`: `Contents/Frameworks/{framework['name']}.framework`, "
                    f"install name `{framework['installName']}`, UUID `{framework['uuid']}`."
                )
            relink_lines.extend([
                "",
                "The framework is built from the static archives under `install/` and",
                "`dependencies/`, each force-loaded unchanged, by",
                "`scripts/package-apple-ffmpeg-runtime-framework.sh`. The exact link command, the",
                "archive checksums, and the toolchain are in `../relink-materials-manifest/`.",
                "",
                "To run the app with modified libraries:",
                "",
                "1. Verify each archive against `../source-offer/SOURCE-CODE.md`, extract it, and",
                "   apply your changes.",
                "2. Rebuild the matching Apple slice with `scripts/build-ffmpeg-apple.sh` and the",
                "   source directory variables documented by that script. Preserve the manifest's",
                "   configure flags so the app finds the functions it calls.",
                "3. Package the framework: `scripts/package-apple-ffmpeg-runtime-framework.sh --build",
                "   --ffmpeg-prefix <install>/<slice> --dependency-prefix <dependencies>/<slice>",
                "   --output-dir <dir>`. Keep the framework name and install name.",
                "4. Replace the framework inside the app bundle and sign the bundle again, inner code",
                "   first: the framework, then the decoder helper XPC service, then the app. Sign all",
                "   three with one identity, or ad hoc with the",
                "   `com.apple.security.cs.disable-library-validation` entitlement on the app and the",
                "   helper; leave out entitlements that need a provisioning profile.",
                "",
                "The app needs no relinking: it binds to the framework's exported symbols at launch.",
            ])
        else:
            relink_lines = [
                "# Static Relinking Instructions",
                "",
                "This artifact uses static SwiftPM linkage. The accompanying source archives, installed",
                "headers, static libraries, configure flags, and checksums provide the library-side inputs",
                "for rebuilding or substituting modified third-party libraries.",
                "",
                "1. Verify each archive against `../source-offer/SOURCE-CODE.md`, then extract it.",
                "2. Rebuild the matching Apple slice with `scripts/build-ffmpeg-apple.sh` and the source",
                "   directory variables documented by that script. Preserve the manifest's configure flags.",
                "3. Replace the corresponding archives under `install/` or `dependencies/` and regenerate",
                "   the artifact manifest and xcconfig with `--package-artifact-root`.",
                "4. Rebuild the consuming app against the regenerated artifact and run its playback gates.",
                "",
                "A final application distributor must retain its own application object files or equivalent",
                "reproducible build inputs needed to relink that application; this SDK artifact cannot supply",
                "application-specific objects. Review that final distribution against the exact licenses.",
            ]
        write_text(stage / "relink-instructions" / "RELINKING.md", "\n".join(relink_lines))

        runtime_capabilities = manifest.get("runtimeCapabilities")
        build_configuration = None
        if isinstance(runtime_capabilities, dict):
            value = runtime_capabilities.get("buildConfiguration")
            if isinstance(value, str) and value.strip():
                build_configuration = value.strip()
                if contains_personal_filesystem_path(build_configuration):
                    raise PacketError(
                        "runtime buildConfiguration contains a personal filesystem path"
                    )
        relink_materials: dict[str, Any] = {
            "artifactManifest": artifact_manifest_path.name,
            "buildConfiguration": build_configuration,
            "requiredConfigureFlags": configure_flags,
            "schemaVersion": 1,
            "sourceArchives": source_archives,
            "staticLibraries": static_libraries,
            "swiftpmLinkMode": link_mode,
        }
        if runtime_frameworks:
            framework_entries = []
            (stage / "relink-materials-manifest").mkdir(parents=True, exist_ok=True)
            for framework in runtime_frameworks:
                record_name = f"{framework['slice']}-FRAMEWORK-RECORD.json"
                shutil.copyfile(
                    framework["recordPath"],
                    stage / "relink-materials-manifest" / record_name,
                )
                framework_entries.append({
                    "binaryRelativePath": framework["binaryRelativePath"],
                    "binarySHA256": framework["binarySHA256"],
                    "installName": framework["installName"],
                    "name": framework["name"],
                    "record": f"distribution/relink-materials-manifest/{record_name}",
                    "relativePath": framework["relativePath"],
                    "slice": framework["slice"],
                    "uuid": framework["uuid"],
                })
            relink_materials["runtimeFrameworks"] = framework_entries
        write_json(stage / "relink-materials-manifest" / "RELINK-MATERIALS.json", relink_materials)

        if output_root.is_symlink():
            raise PacketError(f"distribution output must not be a symlink: {output_root}")
        if output_root.exists():
            if not output_root.is_dir():
                raise PacketError(f"distribution output is not a directory: {output_root}")
            backup_root = artifact_root / f".distribution-backup-{os.getpid()}"
            if backup_root.exists():
                raise PacketError(f"distribution backup path already exists: {backup_root}")
            os.replace(output_root, backup_root)
        os.replace(stage, output_root)
        if backup_root is not None:
            shutil.rmtree(backup_root)
            backup_root = None
        update_artifact_manifests(
            artifact_root,
            distribution_support_entries(output_root),
        )
    except Exception:
        if backup_root is not None and backup_root.exists() and not output_root.exists():
            os.replace(backup_root, output_root)
            backup_root = None
        if stage.exists():
            shutil.rmtree(stage)
        raise

    return len(sources), len(source_archives), len(static_libraries)


def main() -> int:
    arguments = parse_arguments()
    try:
        component_count, source_count, library_count = assemble_packet(
            arguments.artifact_root,
            arguments.provenance,
            arguments.source_archive_root,
        )
    except PacketError as error:
        print(f"error: {error}", file=sys.stderr)
        return 66
    except OSError as error:
        print(f"error: release packet I/O failed: {error}", file=sys.stderr)
        return 74
    print(
        "Assembled FFmpeg artifact release packet: "
        f"{component_count} components, {source_count} verified sources, "
        f"{library_count} static libraries"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
