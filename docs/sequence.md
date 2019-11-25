# Magic Castle Sequence Diagrams

The following sequence diagrams illustrate the inner working of Magic Castle 
once `terraform apply` is called. Some details were left out of the diagrams,
but every diagram is followed by references to the code files that were used
to build the diagram.

## 1. Cluster Creation Sequence

![Cluster Creation Sequence](./diagrams/cluster_creation_sequence.svg)

### References

- [`magic_castle:/common/data.tf`](/common/data.tf)
- [`puppet-magic_castle:/data/terraform_data.yaml.tmpl](https://github.com/ComputeCanada/puppet-magic_castle/blob/master/data/terraform_data.yaml.tmpl)
- [`magic_castle:/openstack/infrastructure.tf](/openstack/infrastructure.tf)
- [`magic_castle:/dns/cloudflare/dns.tf](/dns/cloudflare/dns.tf)
- [`magic_castle:/dns/acme/acme.tf`](/dns/acme/acme.tf)

## 2. Provisioning with Cloud-Init Sequence

![Provisioning with Cloud-Init Sequence](./diagrams/cluster_provisioning_cloud-init_sequence.svg)

### References

- [`magic_castle:/cloud-init/mgmt.yaml`](/cloud-init/mgmt.yaml)
- [`magic_castle:/cloud-init/puppet.yaml](/cloud-init/puppet.yaml)


## 3. Provisioning with Puppet Sequence

![Provisioning with Puppet](./diagrams/cluster_provisioning_puppet_sequence.svg)