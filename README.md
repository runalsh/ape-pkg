# apepkg - Apple Package Engineer

<img src="resources/ape-pkg.png" alt="APE Logo" width="300">

**Build macOS packages on Linux**

`apepkg` is a Linux port of [munki-pkg](https://github.com/munki/munki-pkg) by Greg Neagle, designed for building macOS installer packages (.pkg files) on Linux systems.

> **⚠️ Important**: If you're on macOS, use [munki-pkg](https://github.com/munki/munki-pkg) instead. apepkg is specifically designed for Linux environments where munki-pkg's native Apple tools aren't available.

## What does APE stand for?

**APE** = **A**pple **P**ackage **E**ngineer

Just like how munki-pkg helps you build packages on macOS, apepkg engineers your Apple packages on Linux!

## About This Project

apepkg is a Linux-compatible implementation of munki-pkg's functionality. All credit for the project structure, build-info format, and workflow design goes to **Greg Neagle** and the [munki-pkg project](https://github.com/munki/munki-pkg).

Key differences:
- **munki-pkg**: Uses Apple's native tools (pkgbuild, productbuild) on macOS
- **apepkg**: Uses open-source tools (bomutils, xar) on Linux

Both tools maintain 100% project compatibility - you can use the same project directories with either tool.

## Quick Start

### 1. Install Dependencies (Linux)

```bash
./INSTALL.sh
```

### 2. Create a Package Project

```bash
./apepkg --create MyPackage
```

### 3. Add Your Files

```bash
# Add files to install
mkdir -p MyPackage/payload/usr/local/bin
cp myapp MyPackage/payload/usr/local/bin/

# Add installation scripts (optional)
cat > MyPackage/scripts/postinstall << 'EOF'
#!/bin/bash
echo "Installation complete!"
exit 0
EOF
chmod +x MyPackage/scripts/postinstall
```

### 4. Build the Package

```bash
./apepkg MyPackage
```

Your package is now at `MyPackage/build/MyPackage-1.0.pkg`!

## Docker Usage (Offline Package Builder)

`apepkg` provides an official Docker image (`runalsh/ape-pkg:ubuntu24`) containing all pre-installed dependencies (`apepkg`, `rcodesign`, `xar`, `mkbom`, `lsbom`) for building macOS packages inside a container without installing tools directly on the host system.

### 1. Build local Docker Image (optional)

```bash
docker build -t runalsh/ape-pkg:ubuntu24 .
```

### 2. Build Package Project inside Container

Mount your project directory to `/workspace` inside the container:

```bash
# Build the included HelloWorld example project inside the container
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  runalsh/ape-pkg:ubuntu24 \
  apepkg examples/HelloWorld

# Output package will be created at: examples/HelloWorld/build/HelloWorld-1.0.pkg
```

### 3. Run Custom Build Script inside Container

Execute a custom build script from your project repository inside the container:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  runalsh/ape-pkg:ubuntu24 \
  ./build.sh
```

### 4. Generate Certificate & Sign Package Inside Container

You can generate a self-signed Developer ID Installer PKCS#12 certificate and sign your `.pkg` file with `rcodesign` directly inside the Docker container:

```bash
# 1. Create a self-signed Developer ID Installer certificate (PKCS#12 format)
docker run --rm -v $(pwd):/workspace -w /workspace runalsh/ape-pkg:ubuntu24 bash -c "
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout dev_installer.key \
  -out dev_installer.crt \
  -days 365 \
  -subj '/CN=Developer ID Installer: My Company, O=My Company, C=US'

openssl pkcs12 -export -legacy \
  -out dev_installer.p12 \
  -inkey dev_installer.key \
  -in dev_installer.crt \
  -passout pass:password123
"

# 2. Build and sign package using rcodesign inside container
docker run --rm -v $(pwd):/workspace -w /workspace runalsh/ape-pkg:ubuntu24 bash -c "
apepkg examples/HelloWorld

rcodesign sign \
  --p12-file dev_installer.p12 \
  --p12-password password123 \
  examples/HelloWorld/build/HelloWorld-1.0.pkg
"
```

## Supported Linux Distributions

`apepkg` and its automated `INSTALL.sh` installer have been tested and verified across:

- **Ubuntu**: `22.04 LTS` (Jammy), `24.04 LTS` (Noble), `26.04` (Rolling/Devel)
- **Debian**: `11` (Bullseye), `12` (Bookworm), `testing`
- **Oracle Linux**: `8.x`, `9.x`, `10.x`
- **RHEL / Rocky Linux / AlmaLinux / CentOS**: `8.x`, `9.x`

## Why apepkg?

✅ **Linux-based CI/CD** - Build macOS packages in GitHub Actions, GitLab CI, etc.
✅ **Code signing & notarization** - Sign and notarize packages on Linux with rcodesign
✅ **munki-pkg compatible** - Use the same project structure
✅ **Open source tools** - Uses bomutils and xar instead of proprietary Apple tools
✅ **Git-friendly** - Export/sync BOM for version control
✅ **Distribution packages** - Ready for deployment via MDM, Munki, Jamf, etc.

## Features

- Build standard macOS installer packages (.pkg files)
- Distribution-style packages
- Pre/post installation scripts
- Custom install locations
- Payload and payload-free packages
- **Package importing** - Convert existing packages to projects
- BOM export/sync for git workflows
- Supports plist, JSON, and YAML build-info formats
- **Code signing with Developer ID certificates** (via rcodesign)
- **Apple notarization and ticket stapling** (via rcodesign)
- Advanced build options (compression, min-os-version, large-payload, etc.)

## Code Signing & Notarization

apepkg supports signing and notarizing packages on Linux using [rcodesign](https://github.com/indygreg/apple-platform-rs):

### Install rcodesign

```bash
# Using cargo
cargo install apple-codesign

# Or download pre-built binaries from:
# https://github.com/indygreg/apple-platform-rs/releases
```

### Sign a Package

```bash
# Sign with Developer ID Installer certificate
./apepkg MyPackage \
  --sign \
  --p12-file ~/certs/developer-id-installer.p12 \
  --p12-password-env CERT_PASSWORD
```

### Sign and Notarize

```bash
# Build, sign, and submit for notarization
./apepkg MyPackage \
  --sign \
  --p12-file ~/certs/developer-id-installer.p12 \
  --p12-password-env CERT_PASSWORD \
  --notarize \
  --api-issuer YOUR_TEAM_ID \
  --api-key YOUR_API_KEY_ID
```

**Prerequisites for signing:**
- Apple Developer ID Installer certificate (.p12 file)
- Export from macOS Keychain or obtain from Apple Developer portal

**Prerequisites for notarization:**
- App Store Connect API Key (not Apple ID password)
- API Issuer ID (your Team ID, a UUID like `12345678-abcd-1234-abcd-123456789012`)
- API Key ID (from App Store Connect, like `ABC123XYZ`)
- `.p8` file (AuthKey_<ID>.p8) in a standard location:
  - `~/.appstoreconnect/private_keys/`
  - `~/.private_keys/`
  - `~/private_keys/`
  - `./private_keys/`

**To get an App Store Connect API Key:**
1. Go to https://appstoreconnect.apple.com/access/api
2. Create a new API Key (select "App Manager" role or higher)
3. Note the Issuer ID and Key ID
4. Download the `.p8` file (e.g., `AuthKey_ABC123XYZ.p8`)
5. Place it in `~/.appstoreconnect/private_keys/`

### Obtaining Certificates

On macOS, export your certificate from Keychain:

```bash
# Open Keychain Access, find your "Developer ID Installer" certificate
# Right-click → Export → Save as .p12 file with password
```

## Package Importing

apepkg can import existing flat packages and convert them into apepkg projects:

```bash
# Import a package
./apepkg --import /path/to/existing.pkg MyProject

# The package will be extracted and converted to a project directory:
MyProject/
├── build-info.plist  # Metadata extracted from PackageInfo
├── payload/          # Installed files
├── scripts/          # Pre/post installation scripts
├── Bom.txt          # Bill of Materials
└── build/           # Output directory
```

**Supported:**
- ✅ Distribution-style flat packages (xar archives)
- ✅ Payload extraction
- ✅ Scripts extraction
- ✅ BOM export
- ✅ Metadata preservation (identifier, version, install location, etc.)

**Not Supported:**
- ❌ Bundle-style packages (directory format)

**Note**: Signing and notarization require valid Apple Developer certificates and credentials.

## Documentation

- **[Full Documentation](APEPKG-README.md)** - Complete guide with all features
- **[Quick Start Guide](QUICKSTART.md)** - Step-by-step tutorial
- **[Comparison Table](COMPARISON.md)** - munki-pkg vs apepkg feature comparison
- **[Example Project](examples/HelloWorld/)** - Working example to learn from

## Example Project Structure

```
MyPackage/
├── build-info.plist      # Package metadata (or .json/.yaml)
├── payload/              # Files to install
│   └── usr/
│       └── local/
│           └── bin/
│               └── myapp
├── scripts/              # Installation scripts (optional)
│   ├── preinstall
│   └── postinstall
└── build/               # Output directory (auto-created)
    └── MyPackage-1.0.pkg
```

## CI/CD Example

### GitHub Actions (Build Only)

```yaml
name: Build Package
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install apepkg dependencies
        run: ./INSTALL.sh
      - name: Build package
        run: ./apepkg MyPackage
      - name: Upload artifact
        uses: actions/upload-artifact@v2
        with:
          name: package
          path: MyPackage/build/*.pkg
```

### GitHub Actions (Build, Sign & Notarize)

```yaml
name: Build and Sign Package
on: [push]

jobs:
  build-and-sign:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install apepkg dependencies
        run: ./INSTALL.sh

      - name: Install rcodesign
        run: cargo install apple-codesign

      - name: Decode certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.DEVELOPER_ID_INSTALLER_P12_BASE64 }}
        run: |
          echo "$CERTIFICATE_BASE64" | base64 --decode > cert.p12

      - name: Setup App Store Connect API Key
        env:
          API_KEY_P8_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_P8_BASE64 }}
          API_KEY_ID: ${{ secrets.API_KEY_ID }}
        run: |
          mkdir -p ~/.appstoreconnect/private_keys
          echo "$API_KEY_P8_BASE64" | base64 --decode > ~/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8

      - name: Build, sign, and notarize package
        env:
          CERT_PASSWORD: ${{ secrets.P12_PASSWORD }}
        run: |
          ./apepkg MyPackage \
            --sign \
            --p12-file cert.p12 \
            --p12-password-env CERT_PASSWORD \
            --notarize \
            --api-issuer ${{ secrets.API_ISSUER }} \
            --api-key ${{ secrets.API_KEY_ID }}

      - name: Upload signed package
        uses: actions/upload-artifact@v2
        with:
          name: signed-package
          path: MyPackage/build/*.pkg
```

**Required GitHub Secrets:**
- `DEVELOPER_ID_INSTALLER_P12_BASE64` - Your .p12 certificate (base64 encoded)
- `P12_PASSWORD` - Certificate password
- `API_ISSUER` - App Store Connect API Issuer ID (Team ID UUID)
- `API_KEY_ID` - App Store Connect API Key ID
- `APP_STORE_CONNECT_API_KEY_P8_BASE64` - Your .p8 API key file (base64 encoded)

## Requirements

### Linux System:
- Python 3
- bomutils (mkbom/lsbom)
- xar
- cpio, gzip (usually pre-installed)

Install with:
```bash
./INSTALL.sh
```

Supported distributions:
- Debian/Ubuntu
- Red Hat/Fedora/CentOS
- Other Linux distributions (manual install)

## Command-Line Options

```bash
apepkg [options] pkg_project_directory

Options:
  --create                  Create new empty project
  --import <pkg>            Import existing package and create project
  --json                    Use JSON format for build-info
  --yaml                    Use YAML format for build-info
  --export-bom-info         Export BOM to Bom.txt
  --sync                    Sync permissions from Bom.txt
  --quiet                   Suppress status messages
  -f, --force               Force creation if directory exists

Signing & Notarization:
  --sign                    Sign the package (requires rcodesign)
  --p12-file <path>         Path to .p12 certificate file
  --p12-password <pass>     Certificate password (use --p12-password-env instead)
  --p12-password-env <var>  Environment variable with certificate password
  --notarize                Submit for notarization (requires --sign)
  --api-issuer <uuid>       App Store Connect API Issuer ID (Team ID UUID)
  --api-key <id>            App Store Connect API Key ID (requires .p8 file)
  --notarize-wait           Wait for notarization to complete and staple (default)
  --notarize-no-wait        Don't wait for notarization completion
```

## Hybrid Workflow (Linux + macOS)

You can use both apepkg and munki-pkg with the same project:

```bash
# On Linux (use apepkg)
./apepkg MyPackage

# On macOS (use munki-pkg)
munkipkg MyPackage
```

Both produce identical packages. **Recommendation**: Use munki-pkg on macOS (native Apple tools), and apepkg on Linux (CI/CD pipelines).

## License

Licensed under the Apache License, Version 2.0

## Credits

apepkg is a Linux port of munki-pkg. All credit for the original concept, project structure, and workflow goes to:

- **[munki-pkg](https://github.com/munki/munki-pkg)** by **Greg Neagle** - The original macOS package building tool that this project is based on

Additional tools and inspiration:
- [bomutils](https://github.com/hogliux/bomutils) by Joseph Coffland - BOM creation on Linux
- [xar](https://github.com/mackyle/xar) - Package archive format
- [rcodesign](https://github.com/indygreg/apple-platform-rs) by Gregory Szorc - Cross-platform code signing
- [GytPol's blog post](https://gytpol.com/blog/automating-mac-software-package-process-on-a-linux-based-os) - Initial inspiration for Linux package building

## Contributing

Issues and pull requests welcome.

---

🦍📦
