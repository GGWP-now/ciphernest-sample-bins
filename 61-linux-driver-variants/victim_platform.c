#include <linux/init.h>
#include <linux/module.h>
#include <linux/platform_device.h>

static int victim_platform_probe(struct platform_device *pdev) {
    return 0;
}

static int victim_platform_remove(struct platform_device *pdev) {
    return 0;
}

static struct platform_driver victim_platform_driver = {
    .probe = victim_platform_probe,
    .remove = victim_platform_remove,
    .driver = {
        .name = "victim_platform",
    },
};

static int __init victim_platform_init(void) {
    return platform_driver_register(&victim_platform_driver);
}

static void __exit victim_platform_exit(void) {
    platform_driver_unregister(&victim_platform_driver);
}

module_init(victim_platform_init);
module_exit(victim_platform_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Victim platform driver skeleton");
