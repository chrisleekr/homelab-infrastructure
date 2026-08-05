# Oracle free tier worker

Adds an Oracle Cloud Always Free node to an existing cluster as a worker, and removes it again.

| Step | Roughly | What you end up with |
|---|---|---|
| [1. Roll Tailscale to the LAN cluster](#1-roll-tailscale-to-the-lan-cluster) | 20 min | Every existing node on the tailnet, advertising its own `/32` |
| [2. Provision the node](#2-provision-the-node) | 10 min to several days | An Ampere A1 instance on the tailnet. Oracle capacity decides which |
| [3. Register it as a worker](#3-register-it-as-a-worker) | 5 min | A `worker_hosts_json` entry with the node's tailnet address |
| [4. Join it to the cluster](#4-join-it-to-the-cluster) | 15 min | A `Ready` arm64 node, tainted so nothing schedules onto it by accident |
| [5. Check the node works](#5-check-the-node-works) | 5 min | |
| [6. Check the cloud firewall is closed](#6-check-the-cloud-firewall-is-closed) | 5 min | Proof that nothing is reachable from the internet |
| [7. Check MTU across the tunnel](#7-check-mtu-across-the-tunnel) | 10 min | Either working large-payload traffic, or a known limit |

Everything here is opt-in. With `tailscale_node_enable` unset and stage 0 never applied, none of it runs and the LAN cluster is untouched.

## Before you start

This page starts from a **cloud account that is already set up**. If you have not done that, it is [Account setup](../stage0/oci-freetier.md#account-setup) and takes about 45 minutes of console clicking. Come back here afterwards.

You also need, all covered by that page:

- A tailnet policy defining `tag:k8s-node`, with `autoApprovers.routes` on the LAN `/24`. Without it every node route needs approving by hand and the `/32` stays inert.
- A Tailscale auth key tagged `tag:k8s-node`, expiry 1 day, which is the minimum the console form accepts.
- A working `task stage0:terraform:plan`.

If you want to understand what you are building before you build it, read [Cloud architecture](../stage0/architecture.md) first. It is short.

## 1. Roll Tailscale to the LAN cluster

Do this as its own change, **before any cloud node exists**. It separates "did the Tailscale change break something" from "did the new node break something", and the first one has bitten this cluster before.

```bash
bws secret create tailscale_node_enable "true" "$BWS_PROJECT_ID"
bws secret create tailscale_auth_key    "tskey-auth-..." "$BWS_PROJECT_ID"
task stage1:ansible:playbook
```

Then confirm, from the Tailscale admin console and the cluster:

```bash
tailscale status --json | jq '.Peer[] | {HostName, PrimaryRoutes}'   # each node's own /32 approved
kubectl get nodes                                                     # all still Ready
```

!!! danger "Never set `--accept-routes` on a LAN node"

    It belongs on cloud nodes only, which is where `stage0/oci-freetier/templates/cloud-init.yaml.tftpl` sets it. Why it cuts a LAN node's own connectivity, and how to recover over the tailnet, is in the [`tailscale_node` role page](../stage1/roles/tailscale-node.md).

## 2. Provision the node

```bash
task stage0:terraform:plan
task stage0:terraform:apply:retry
```

Expect "Out of host capacity" on an unupgraded account, possibly for days. That is what the retry task is for, and it logs every attempt so you can leave it running. See [capacity retries](../stage0/oci-freetier.md#capacity-retries).

Confirm the node reached the tailnet and carries the right tag:

```bash
tailscale status | grep oci-worker
```

Then **revoke the auth key** in the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys). The copy inside `user_data` stays readable from IMDS for the life of the instance, so anything that gets code execution on the node can mint more `tag:k8s-node` devices. Tailscale burns a one-off key on use, so this only matters for the reusable key a multi-node apply needs, which is exactly the dangerous case.

!!! danger "If it never appears on the tailnet, destroy it"

    UFW closes before Tailscale is installed, so a node that fails to join has no reachable SSH path and its auth key is already deleted. There is no way back in. This is deliberate, and the reasoning is in [First boot](../stage0/architecture.md#first-boot). Destroy and re-provision rather than trying to recover.

## 3. Register it as a worker

`node_ip` is the one field Terraform cannot produce, because it does not know the tailnet address. Read it, then append the entry to `worker_hosts_json`:

```bash
task stage0:terraform:output
tailscale status | grep oci-worker    # the 100.x.y.z address
```

The resulting object, with `node_ip` filled in:

```json
{"name":"oci-worker-01","host":"oci-worker-01","user":"ubuntu","node_ip":"100.x.y.z","snapd_purge":false,"taints":[{"key":"node.homelab/class","value":"cloud","effect":"NoSchedule"}],"labels":{"node.homelab/class":"cloud"}}
```

`host` is the Tailscale MagicDNS name. Why `snapd_purge` is false and why the taint value is `cloud` are both in [Handing the node to Stage 1](../stage0/architecture.md#handing-the-node-to-stage-1).

## 4. Join it to the cluster

```bash
task stage1:ansible:ping                  # reaches oci-worker-01 over the tailnet
task stage1:ansible:playbook:worker
```

## 5. Check the node works

```bash
kubectl get nodes -o wide                                        # Ready, arm64, INTERNAL-IP 100.x.y.z
kubectl describe node oci-worker-01 | grep -A2 Taints
kubectl -n kube-system exec ds/cilium -- cilium-health status     # reachable both directions
kubectl debug node/oci-worker-01 -it --image=busybox -- true      # apiserver to kubelet on 10250
```

Then confirm nothing else moved: every LAN node still `Ready`, and `kubectl logs` still works against a pod on the LAN.

## 6. Check the cloud firewall is closed

This is the step that proves the node is not exposed to the internet. Run the first two from a personal tailnet device, the rest on the node itself:

```bash
nc -vz -w 5 <oci-tailnet-ip> 10250                     # must TIME OUT
nc -vz -w 5 <oci-public-ip> 22                         # must TIME OUT, run from outside every stage0_ssh_ingress_cidrs source
sudo ufw status verbose                                # must report Status: active
sudo sshd -T | grep -E 'passwordauthentication|kbdinteractiveauthentication'   # both no
sudo systemctl is-enabled netfilter-persistent         # must be enabled, or rules.v4 is inert at boot
curl -s -o /dev/null -w '%{http_code}\n' http://169.254.169.254/opc/v1/instance/   # must print 404
snap list | grep oracle-cloud-agent                    # agent survived stage 1
```

**A timeout, not a refusal, is the pass condition.** OCI security rules, UFW `deny` and Tailscale ACLs all drop silently rather than sending a RST, so an immediate "Connection refused" and a successful connect both mean the posture is broken. Bound every check with `-w` or `nc` can hang for minutes.

Two of these are easy to get wrong:

- **Check the public IP explicitly**, not just the tailnet address. The tailnet check passes whether or not the cloud-side firewall is correct, so on its own it proves nothing about internet exposure. Read the address with `cd stage0 && terraform output public_ips` after the workspace is selected; `task stage0:terraform:output` prints only the worker entries.
- **The IMDSv1 check needs the status code.** Plain `curl` treats the 404 as a completed transfer and exits 0, so it looks identical to success.

## 7. Check MTU across the tunnel

!!! warning "This is a known unresolved limit, not a pass/fail gate"

    The tailnet path is 1280 bytes and Cilium is pinned to a 1500-byte cluster MTU, so pod traffic to the cloud node above roughly 1230 bytes has nowhere to go. The failure mode is a **stall with no error**, which is why it is worth provoking deliberately now rather than meeting it in production weeks later.

    Why the pin exists and what the options are: [MTU and the Cilium pin](../stage1/architecture.md#mtu-and-the-cilium-pin).

Put a pod on each side and push more than one MTU through:

```bash
kubectl run mtu-probe-cloud --image=busybox --restart=Never \
  --overrides='{"spec":{"nodeName":"oci-worker-01","tolerations":[{"key":"node.homelab/class","operator":"Exists","effect":"NoSchedule"}]}}' \
  -- sleep 3600
kubectl run mtu-probe-lan --image=busybox --restart=Never -- sleep 3600
kubectl get pod mtu-probe-cloud -o jsonpath='{.status.podIP}'
```

Listen on the cloud pod, then send from the LAN pod in a second terminal:

```bash
kubectl exec mtu-probe-cloud -- sh -c 'nc -l -p 8080 > /dev/null'
kubectl exec mtu-probe-lan   -- sh -c 'head -c 1000000 /dev/urandom | nc <cloud-pod-ip> 8080'
```

A megabyte should move in about a second. If it hangs, the path is black-holing anything over the tunnel MTU, and this node cannot carry large pod-to-pod payloads until that is settled. Clean up with `kubectl delete pod mtu-probe-cloud mtu-probe-lan`.

## Tear down

```bash
kubectl drain oci-worker-01 --ignore-daemonsets --delete-emptydir-data
kubectl delete node oci-worker-01
task stage0:terraform:init
cd stage0 && terraform destroy
```

Then remove the node's object from `worker_hosts_json` and **delete the device from the Tailscale admin console**. Destroying the instance leaves the device record behind, and a stale record holds the MagicDNS name, so re-provisioning under the same name would get a `-1` suffix instead.

The `homelab` compartment, the group, the user and the policy all survive `terraform destroy`, because [account setup](../stage0/oci-freetier.md#account-setup) creates them and Terraform never owns them. Leave them in place to re-provision later, or delete them by hand in the console to close the account down.
