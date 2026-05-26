# macOS Driver Variant Victims

Safe skeletons for the two common macOS driver families:

- legacy IOKit kernel extension (`kext`)
- DriverKit user-space system extension (`dext`) entry surface

The script compiles object files only on macOS and never installs or loads
kernel extensions or system extensions.

```sh
sh build.sh build
```
