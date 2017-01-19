#! /usr/bin/env bats

load ../environment

setup() {
  test_filter
  @go.create_test_go_script '@go "$@"'
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: show help if too few or too many args" {
  run test-go get file
  assert_failure
  assert_output_matches "^test-go get file - Downloads a single file"

  run test-go get file -f foobar.txt bazquux.txt xyzzy
  assert_failure
  assert_output_matches "^test-go get file - Downloads a single file"
}

@test "$SUITE: tab completion" {
  run "$TEST_GO_SCRIPT" get file --complete 0
  assert_success '-f'

  local expected=("$TEST_GO_ROOTDIR"/*)
  test_join $'\n' expected "${expected[@]#$TEST_GO_ROOTDIR/}"

  run "$TEST_GO_SCRIPT" get file --complete 1 -f
  assert_success "$expected"
}

@test "$SUITE: fail if neither curl nor wget installed" {
  PATH= run "$BASH" "$TEST_GO_SCRIPT" get file foobar.txt
  assert_failure 'Please install curl or wget before running "get file".'
}

@test "$SUITE: curl called with correct args with URL only" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    http://localhost/foobar.txt
  assert_success '-L -o foobar.txt http://localhost/foobar.txt' \
    'Downloaded "http://localhost/foobar.txt" as: foobar.txt'
}

@test "$SUITE: curl called with correct args with output file" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f barbaz.txt http://localhost/foobar.txt
  assert_success '-L -o barbaz.txt http://localhost/foobar.txt' \
    'Downloaded "http://localhost/foobar.txt" as: barbaz.txt'
}

@test "$SUITE: curl called with correct args for standard output" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f - http://localhost/foobar.txt
  assert_success '-L http://localhost/foobar.txt'
}

@test "$SUITE: curl called with correct args for local relative path" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  mkdir -p "$TEST_GO_ROOTDIR"
  printf '' >"$TEST_GO_ROOTDIR/foobar.txt"
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file -f - foobar.txt
  assert_success "-L file://$TEST_GO_ROOTDIR/foobar.txt"
}

@test "$SUITE: curl called with correct args for local absolute path" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  mkdir -p "$TEST_GO_ROOTDIR"
  printf '' >"$TEST_GO_ROOTDIR/foobar.txt"
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file -f - \
    "$TEST_GO_ROOTDIR/foobar.txt"
  assert_success "-L file://$TEST_GO_ROOTDIR/foobar.txt"
}

@test "$SUITE: wget called with correct args with URL only" {
  stub_program_in_path 'wget' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    http://localhost/foobar.txt
  assert_success '-O foobar.txt http://localhost/foobar.txt' \
    'Downloaded "http://localhost/foobar.txt" as: foobar.txt'
}

@test "$SUITE: wget called with correct args with output file" {
  stub_program_in_path 'wget' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f barbaz.txt http://localhost/foobar.txt
  assert_success '-O barbaz.txt http://localhost/foobar.txt' \
    'Downloaded "http://localhost/foobar.txt" as: barbaz.txt'
}

@test "$SUITE: wget called with correct args for standard output" {
  stub_program_in_path 'wget' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f - http://localhost/foobar.txt
  assert_success '-O - http://localhost/foobar.txt'
}

@test "$SUITE: curl called with existing output directory" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  mkdir -p "$TEST_GO_ROOTDIR/bazquux"
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f bazquux http://localhost/foobar.txt
  assert_success '-L -o bazquux/foobar.txt http://localhost/foobar.txt' \
    'Downloaded "http://localhost/foobar.txt" as: bazquux/foobar.txt'
}

@test "$SUITE: curl called with new output directory" {
  stub_program_in_path 'curl' 'printf "%s\n" "$*"'
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f bazquux/xyzzyplugh.txt http://localhost/foobar.txt
  assert_success '-L -o bazquux/xyzzyplugh.txt http://localhost/foobar.txt' \
    'Downloaded "http://localhost/foobar.txt" as: bazquux/xyzzyplugh.txt'
}

@test "$SUITE: fail if file already exists" {
  stub_program_in_path 'curl' 'echo Should not see this'
  printf '' >"$TEST_GO_ROOTDIR/foobar.txt"
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    http://localhost/foobar.txt
  assert_failure 'File already exists; not overwriting: foobar.txt'
}

@test "$SUITE: fail if download directory can't be created" {
  skip_if_cannot_trigger_file_permission_failure

  stub_program_in_path 'curl' 'echo Should not see this'
  chmod ugo-w "$TEST_GO_ROOTDIR"

  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f bad-parent/innocent-child.txt http://localhost/foobar.txt
  assert_failure
  assert_output_matches \
    $'\nDownload dir doesn\'t exist and can\'t be created: bad-parent$'
}

@test "$SUITE: fail if download directory can't be written to" {
  skip_if_cannot_trigger_file_permission_failure

  stub_program_in_path 'curl' 'echo Should not see this'
  mkdir -p "$TEST_GO_ROOTDIR/barbaz"
  chmod ugo-w "$TEST_GO_ROOTDIR/barbaz"

  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" get file \
    -f barbaz http://localhost/foobar.txt
  assert_failure "You don't have permission to write to download dir: barbaz"
}

@test "$SUITE: show failure message if curl fails" {
  stub_program_in_path 'curl' 'printf "Oh noes!\n" >&2' 'exit 1'
  run "$TEST_GO_SCRIPT" get file http://localhost/foobar.txt
  assert_failure 'Oh noes!' 'Failed to download: http://localhost/foobar.txt'
}

@test "$SUITE: use real curl to copy a local file" {
  skip_if_system_missing 'curl'

  local source_path="$TEST_GO_ROOTDIR/hello.txt"
  local download_path="$TEST_GO_ROOTDIR/download.txt"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf 'Hello, World!\n' >"$source_path"
  run "$TEST_GO_SCRIPT" get file -f "$download_path" "$source_path"

  assert_success "Downloaded \"file://$source_path\" as: $download_path"
  assert_file_equals "$download_path" 'Hello, World!'
}

@test "$SUITE: use real curl to print a local file to standard output" {
  skip_if_system_missing 'curl'

  local source_path="$TEST_GO_ROOTDIR/hello.txt"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf 'Hello, World!\n' >"$source_path"
  run "$TEST_GO_SCRIPT" get file -f - "$source_path"

  assert_success 'Hello, World!'
}

@test "$SUITE: show failure message if real wget fails" {
  skip_if_system_missing 'wget'

  # We have to use a stub and manipulate `PATH` since `./go get` will try to use
  # `curl` first. The setup below is predicated on the notion that `wget` will
  # be installed somewhere other than `/bin`.
  if [[ -x '/bin/wget' ]]; then
    skip "can't stub out system wget"
  fi
  stub_program_in_path 'wget' "$(command -v 'wget') \"\$@\""

  # It turns out that `wget` isn't equipped to handle `file://` URLs, so we
  # produce a real failure by trying to fetch a local file.
  local source_path="$TEST_GO_ROOTDIR/hello.txt"

  mkdir -p "$TEST_GO_ROOTDIR"
  printf 'Hello, World!\n' >"$source_path"
  PATH="${PATH%%:*}:/bin" run "$BASH" "$TEST_GO_SCRIPT" \
    get file -f - "$source_path"

  # Note that `wget` uses "smart" quotes around `file` on some platforms, so we
  # have to use a regex.
  assert_failure
  assert_lines_match "^file://$source_path: Unsupported scheme .file.\.$" \
    "^Failed to download: file://$source_path$" \
    '^Consider installing `curl` and trying again\.$'
}