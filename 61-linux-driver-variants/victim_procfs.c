#include <linux/init.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>

static struct proc_dir_entry *victim_proc;

static int victim_proc_show(struct seq_file *m, void *v) {
    seq_puts(m, "victim procfs driver\n");
    return 0;
}

static int victim_proc_open(struct inode *inode, struct file *file) {
    return single_open(file, victim_proc_show, NULL);
}

static const struct proc_ops victim_proc_ops = {
    .proc_open = victim_proc_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

static int __init victim_procfs_init(void) {
    victim_proc = proc_create("victim_procfs", 0444, NULL, &victim_proc_ops);
    return victim_proc ? 0 : -ENOMEM;
}

static void __exit victim_procfs_exit(void) {
    proc_remove(victim_proc);
}

module_init(victim_procfs_init);
module_exit(victim_procfs_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Victim procfs driver skeleton");
