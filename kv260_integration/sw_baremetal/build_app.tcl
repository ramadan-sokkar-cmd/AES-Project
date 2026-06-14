# ============================================================================
# AES-128 Baremetal App Build (second step — platform already generated)
# ============================================================================
# Run after build_baremetal.tcl has completed platform generation.
# Usage: xsct build_app.tcl
# ============================================================================

set PROJECT_ROOT    [file normalize "C:/Work/Eitesal_EG/SMC26-24/kv260_integration"]
set WORKSPACE       [file normalize "$PROJECT_ROOT/sw_baremetal/workspace"]
set APP_NAME        "aes_baremetal"
set PLATFORM_NAME   "aes_platform"

setws $WORKSPACE

set PLATFORM_XPFM [file normalize "$WORKSPACE/$PLATFORM_NAME/export/$PLATFORM_NAME/$PLATFORM_NAME.xpfm"]

# ---- Create application (platform already exists in workspace) ----
puts ">>> Creating application '$APP_NAME'..."
puts ">>> Platform: $PLATFORM_XPFM"
app create -name $APP_NAME \
    -platform $PLATFORM_XPFM \
    -domain standalone_domain \
    -template "Empty Application"

# ---- Import source files ----
puts ">>> Importing source files..."
importsources -name $APP_NAME -path [file normalize "$PROJECT_ROOT/sw_baremetal/aes_baremetal.c"]
importsources -name $APP_NAME -path [file normalize "$PROJECT_ROOT/sw_baremetal/aes_hw.h"]

# ---- Build application ----
puts ">>> Building application..."
app build -name $APP_NAME

# ---- Report ----
set elf_path [file normalize "$WORKSPACE/$APP_NAME/Debug/${APP_NAME}.elf"]
puts "\n=============================================="
puts "  BUILD COMPLETE"
puts "=============================================="
puts "  ELF: $elf_path"
if {[file exists $elf_path]} {
    puts "  Size: [file size $elf_path] bytes"
    puts "  Status: OK"
} else {
    puts "  Status: WARNING — ELF not found at expected path"
}
puts "=============================================="
