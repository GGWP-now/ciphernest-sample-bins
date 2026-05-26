# Linux Driver Variant Victims

Safe Linux kernel module skeletons for common driver shapes:

- character device registration
- misc device registration
- platform driver registration
- virtual netdev registration
- procfs entry registration
- safeguarded module-parameter variant

The build script requires Linux kernel headers. It only builds `.ko` files and
does not insert or load modules.

```sh
sh build.sh build
```
