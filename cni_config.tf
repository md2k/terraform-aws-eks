// CNI Custom Resource Definition Configuration
resource "local_file" "cni_eni_crd" {
  content  = "${data.template_file.cni_eni_crd.rendered}"
  filename = "${var.config_output_path}cni-eni-crd-${var.cluster_name}.yaml"
  count    = "${length(var.pod_subnets) > 0 ? 1 : 0}"
}

resource "null_resource" "cni_eni_crd" {
  depends_on = ["null_resource.update_config_map_aws_auth"]

  provisioner "local-exec" {
    command     = "for i in {1..5}; do kubectl apply -f ${var.config_output_path}cni_eni_crd_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig_${var.cluster_name} && break || sleep 10; done"
    interpreter = ["${var.local_exec_interpreter}"]
  }

  triggers {
    config_map_rendered = "${data.template_file.cni_eni_crd.rendered}"
  }

  count = "${length(var.pod_subnets) > 0 ? 1 : 0}"
}

data "template_file" "cni_eni_crd" {
  template = "${file("${path.module}/templates/cni-eni-crd.yaml.tpl")}"
}

// CNI Networks eniConfg resources
resource "local_file" "cni_eni_netconfig" {
  content  = "${element(data.template_file.cni_eni_netconfig.*.rendered, count.index)}"
  filename = "${var.config_output_path}cni-eni-netconfig-${data.aws_availability_zones.available.names[count.index]}-${var.cluster_name}.yaml"
  count    = "${length(var.pod_subnets) > 0 ? length(var.pod_subnets) : 0}"
}

resource "null_resource" "cni_eni_netconfig" {
  depends_on = ["null_resource.cni_eni_crd"]

  provisioner "local-exec" {
    command     = "for i in {1..5}; do kubectl apply -f ${var.config_output_path}cni-eni-netconfig-${data.aws_availability_zones.available.names[count.index]}-${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig_${var.cluster_name} && break || sleep 10; done"
    interpreter = ["${var.local_exec_interpreter}"]
  }

  triggers {
    config_map_rendered = "${element(data.template_file.cni_eni_netconfig.*.rendered, count.index)}"
  }

  count = "${length(var.pod_subnets) > 0 ? length(var.pod_subnets) : 0}"
}

data "template_file" "cni_eni_netconfig" {
  template = "${file("${path.module}/templates/cni-eni-pod-netconfig.yaml.tpl")}"

  vars {
    eni_pod_netconfig_name  = "${data.aws_availability_zones.available.names[count.index]}"
    eni_pod_subnet          = "${element(var.pod_subnets,count.index)}"
    workers_security_groups = "${join("\n    - ", aws_launch_configuration.workers.0.security_groups)}"
  }

  count = "${length(var.pod_subnets) > 0 ? length(var.pod_subnets) : 0}"
}

// Patch AWS-NODE Deployment to enable Custom CNI configuration
resource "null_resource" "aws_node_patcher" {
  depends_on = ["null_resource.cni_eni_netconfig"]

  provisioner "local-exec" {
    command     = "for i in {1..5}; do kubectl patch daemonset -n kube-system aws-node --type=json -p='[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/env/-\", \"value\":{\"name\": \"AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG\", \"value\": \"true\"}}]' --kubeconfig ${var.config_output_path}kubeconfig_${var.cluster_name} && break || sleep 10; done"
    interpreter = ["${var.local_exec_interpreter}"]
  }
}
