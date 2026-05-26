#include <linux/etherdevice.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/netdevice.h>

static struct net_device *victim_netdev;

static int victim_open(struct net_device *dev) {
    netif_start_queue(dev);
    return 0;
}

static int victim_stop(struct net_device *dev) {
    netif_stop_queue(dev);
    return 0;
}

static const struct net_device_ops victim_netdev_ops = {
    .ndo_open = victim_open,
    .ndo_stop = victim_stop,
};

static void victim_setup(struct net_device *dev) {
    ether_setup(dev);
    dev->netdev_ops = &victim_netdev_ops;
}

static int __init victim_netdev_init(void) {
    victim_netdev = alloc_netdev(0, "victim%d", NET_NAME_UNKNOWN, victim_setup);
    if (!victim_netdev) {
        return -ENOMEM;
    }
    return register_netdev(victim_netdev);
}

static void __exit victim_netdev_exit(void) {
    if (victim_netdev) {
        unregister_netdev(victim_netdev);
        free_netdev(victim_netdev);
    }
}

module_init(victim_netdev_init);
module_exit(victim_netdev_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Victim netdev driver skeleton");
