apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: ${eni_pod_netconfig_name}
spec:
  subnet: ${eni_pod_subnet}
  securityGroups:
    - ${workers_security_groups}
