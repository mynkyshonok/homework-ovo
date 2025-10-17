terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
	zone = "ru-central1-b"
	cloud_id = "b1gcb601ueejg02ons9c"
	folder_id = "b1g0g8udg3mbttqccmm8"
}

resource "yandex_compute_instance" "vm" {
  count = 2

  name = "vm${count.index}"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd86rorl7r6l2nq3ate6"
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my-subnet.id
    nat       = true
  }

  metadata = { ssh-keys = "tymka:${file("~/ssh-key-my.pub")}" }
}

resource "yandex_vpc_network" "my-network" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "my-subnet" {
  name		 = "my_subnet"
  network_id     = yandex_vpc_network.my-network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_lb_target_group" "my-group" {
  name = "my-group"
  
  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.my-subnet.id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "my-balancer" {
  name                = "my-balancer"
  deletion_protection = "false"
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  
  attached_target_group {
    target_group_id = yandex_lb_target_group.my-group.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
