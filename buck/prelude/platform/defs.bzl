# SPDX-FileCopyrightText: © 2022 Meta Platforms, Inc. and affiliates.
# SPDX-FileCopyrightText: © 2022 Austin Seipp
# SPDX-License-Identifier: MIT OR Apache-2.0

# @prelude//platform/defs.bzl -- platform and host definitions
#
# HOW TO USE THIS MODULE:
#
#    load("@prelude//platform/defs.bzl", "host_config")

"""Platform and host definitions."""

## ---------------------------------------------------------------------------------------------------------------------

def _execution_platform_impl(ctx: "context") -> ["provider"]:
    constraints = dict()
    constraints.update(ctx.attrs.cpu_configuration[ConfigurationInfo].constraints)
    constraints.update(ctx.attrs.os_configuration[ConfigurationInfo].constraints)
    cfg = ConfigurationInfo(constraints = constraints, values = {})

    name = ctx.label.raw_target()

    if ctx.attrs.remote_enabled:
        exe_cfg = CommandExecutorConfig(
            local_enabled = True,
            remote_enabled = True,
            use_limited_hybrid = True,
            use_windows_path_separators = False,
            remote_execution_properties = {
                "OSFamily": "Linux",
                "container-image": "nixos/nix:2.15.0@sha256:251a921be086aa489705e31fa5bd59f2dadfa0824aa7f362728dfe264eb6a3d2",
            },
            remote_execution_use_case = "buck2-default",
            remote_output_paths = "strict",
        )
    else:
        exe_cfg = CommandExecutorConfig(
            local_enabled = True,
            remote_enabled = False,
            use_windows_path_separators = False,
        )

    exe_platform = ExecutionPlatformInfo(
        label = name,
        configuration = cfg,
        executor_config = exe_cfg,
    )

    return [
        DefaultInfo(),
        exe_platform,
        PlatformInfo(label = str(name), configuration = cfg),
        ExecutionPlatformRegistrationInfo(platforms = [exe_platform]),
    ]

__execution_platform = rule(
    impl = _execution_platform_impl,
    attrs = {
        "cpu_configuration": attrs.dep(providers = [ConfigurationInfo]),
        "os_configuration": attrs.dep(providers = [ConfigurationInfo]),
        "remote_enabled": attrs.bool(default = False),
    },
)

def _host_cpu_configuration() -> str.type:
    arch = host_info().arch
    if arch.is_aarch64:
        return "prelude//platform/cpu:aarch64"
    else:
        return "prelude//platform/cpu:x86_64"

def _host_os_configuration() -> str.type:
    os = host_info().os
    if os.is_macos:
        return "prelude//platform/os:darwin"
    else:
        return "prelude//platform/os:linux"

host_config = struct(
    cpu = _host_cpu_configuration(),
    os = _host_os_configuration(),
)

def generate_platforms(variants):
    """Generate execution platforms for the given variants, as well as a default
    execution platform matching the host platform."""

    for (cpu, os) in variants:
        cpu_configuration = "prelude//platform/cpu:{}".format(cpu)
        os_configuration = "prelude//platform/os:{}".format(os)
        visibility = [ "prelude//..." ]

        __execution_platform(
            name = "{}-{}".format(cpu, os),
            cpu_configuration = cpu_configuration,
            os_configuration = os_configuration,
            visibility = visibility,
        )

        __execution_platform(
            name = "{}-{}-remote".format(cpu, os),
            cpu_configuration = cpu_configuration,
            os_configuration = os_configuration,
            remote_enabled = True,
            visibility = visibility,
        )

    use_remote_by_default = False
    if host_info().os.is_linux and not host_info().arch.is_aarch64:
        use_remote_by_default = False # XXX FIXME (aseipp): True, when buildbarn is ready

    __execution_platform(
        name = "default",
        cpu_configuration = _host_cpu_configuration(),
        os_configuration = _host_os_configuration(),
        remote_enabled = use_remote_by_default,
        visibility = [ "prelude//..." ],
    )
