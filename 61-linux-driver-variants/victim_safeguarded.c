#include <linux/init.h>
#include <linux/module.h>
#include <linux/moduleparam.h>

static int victim_limit = 16;
module_param(victim_limit, int, 0444);
MODULE_PARM_DESC(victim_limit, "bounded test value from 0 to 1024");

static int __init victim_safeguarded_init(void) {
    if (victim_limit < 0 || victim_limit > 1024) {
        return -EINVAL;
    }
    return 0;
}

static void __exit victim_safeguarded_exit(void) {
}

module_init(victim_safeguarded_init);
module_exit(victim_safeguarded_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Safeguarded victim driver skeleton");
