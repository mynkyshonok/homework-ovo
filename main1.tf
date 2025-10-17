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

resource "yandex_compute_instance_group" "vm-group" {

  name = "vm-group"
  service_account_id  = "aje2n4n0akl964kupfe3"
  instance_template {
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
      subnet_ids = ["${yandex_vpc_subnet.my-subnet.id}"]
      nat       = true
    }

    metadata = { 
      ssh-keys = "tymka:${file("~/ssh-key-my.pub")}" 
      user-data = file("./metadata.yaml")
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }  
 
  allocation_policy {
    zones = ["ru-central1-b"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  load_balancer {
    target_group_name        = "target-group"
    target_group_description = "Целевая группа Network Load Balancer"
  }
}

resource "yandex_vpc_network" "my-network" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "my-subnet" {
  name		 = "my_subnet"
  network_id     = yandex_vpc_network.my-network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
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
    target_group_id = yandex_compute_instance_group.vm-group.load_balancer.0.target_group_id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
