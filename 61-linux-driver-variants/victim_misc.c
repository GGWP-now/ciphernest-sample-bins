#include <linux/fs.h>
#include <linux/init.h>
#include <linux/miscdevice.h>
#include <linux/module.h>

static int victim_misc_open(struct inode *inode, struct file *file) {
    return 0;
}

static const struct file_operations victim_misc_fops = {
    .owner = THIS_MODULE,
    .open = victim_misc_open,
};

static struct miscdevice victim_misc = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "victim_misc",
    .fops = &victim_misc_fops,
};

static int __init victim_misc_init(void) {
    return misc_register(&victim_misc);
}

static void __exit victim_misc_exit(void) {
    misc_deregister(&victim_misc);
}

module_init(victim_misc_init);
module_exit(victim_misc_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Victim misc driver skeleton");
