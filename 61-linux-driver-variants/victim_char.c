#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/module.h>

static dev_t victim_dev;
static struct cdev victim_cdev;

static int victim_open(struct inode *inode, struct file *file) {
    return 0;
}

static const struct file_operations victim_fops = {
    .owner = THIS_MODULE,
    .open = victim_open,
};

static int __init victim_char_init(void) {
    int status = alloc_chrdev_region(&victim_dev, 0, 1, "victim_char");
    if (status) {
        return status;
    }
    cdev_init(&victim_cdev, &victim_fops);
    return cdev_add(&victim_cdev, victim_dev, 1);
}

static void __exit victim_char_exit(void) {
    cdev_del(&victim_cdev);
    unregister_chrdev_region(victim_dev, 1);
}

module_init(victim_char_init);
module_exit(victim_char_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Victim char driver skeleton");
