output "node_addresses" {
  description = "Public SSH and private cluster IPs for each Ubuntu 22.04 VM."
  value = {
    for name, vm in aws_instance.node : name => {
      public_ip  = vm.public_ip
      private_ip = vm.private_ip
    }
  }
}

output "frontend_url" {
  description = "Demo frontend URL after applying Kubernetes manifests."
  value       = "http://${aws_instance.node["k8s-control"].public_ip}:30080"
}
