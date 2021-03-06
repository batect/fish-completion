set __fish_batect_proxy_loaded_versions

function __fish_batect_proxy_complete_for_current_version
    set -l tokens (commandline -opc) (commandline -ct)
    set -l wrapper_script_path $tokens[1]
    set -l cut_command_line_at (math (string length "$wrapper_script_path") + 2)
    set -l command_line_without_wrapper (string sub --start $cut_command_line_at (commandline -pc))

    if test ! -x $wrapper_script_path
        # If the wrapper script doesn't exist, fallback to as if this completion script doesn't exist.
        complete -C"batect-completion-proxy-nonsense $command_line_without_wrapper"
        return
    end

    set -l batect_version (cat $wrapper_script_path | string match --regex 'VERSION="(.*)"' | awk 'NR == 2')
    set -l use_disk_cache "true"

    if test "$batect_version" != ""
        set -l batect_version_major (string split "." -- $batect_version)[1]
        set -l batect_version_minor (string split "." -- $batect_version)[2]

        if test \( $batect_version_major -eq 0 \) -a \( $batect_version_minor -lt 62 \)
            # If we know what the version is, and it's too old, fallback to as if this completion script doesn't exist.
            complete -C"batect-completion-proxy-nonsense $command_line_without_wrapper"
            return
        end
    else
        # HACK: this makes it easier to test completions locally when testing with the start script generated by Gradle.
        set batect_version "0.0.0-local-dev"
        set use_disk_cache "false"
    end

    set -lx BATECT_COMPLETION_PROXY_REGISTER_AS "batect-$batect_version"
    set -lx BATECT_COMPLETION_PROXY_VERSION "0.6.0-dev"
    set -lx BATECT_COMPLETION_PROXY_WRAPPER_PATH $wrapper_script_path

    if not contains $batect_version $__fish_batect_proxy_loaded_versions
        __fish_batect_proxy_load_completion_script "$wrapper_script_path" "$batect_version" "$use_disk_cache"
    end

    complete -C"$BATECT_COMPLETION_PROXY_REGISTER_AS $command_line_without_wrapper"
end

function __fish_batect_proxy_load_completion_script --argument-names wrapper_script_path batect_version use_disk_cache
    set -l disk_cache_root "$HOME/.batect/completion/fish-wrapper-$BATECT_COMPLETION_PROXY_VERSION"
    set -l disk_cache_path "$disk_cache_root/$batect_version"
    set -l completion_script

    if test \( "$use_disk_cache" = "true" \) -a \( -f "$disk_cache_path" \)
        set completion_script (cat "$disk_cache_path" | string collect)
    else
        set completion_script (BATECT_QUIET_DOWNLOAD=true $wrapper_script_path --generate-completion-script=fish | string collect)
    end

    eval $completion_script
    set -a __fish_batect_proxy_loaded_versions $batect_version

    if test \( "$use_disk_cache" = "true" \) -a \( ! -f "$disk_cache_path" \)
        mkdir -p "$disk_cache_root"
        echo "$completion_script" > "$disk_cache_path"
    end
end

complete -c batect -x -a "(__fish_batect_proxy_complete_for_current_version)"
