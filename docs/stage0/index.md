# Cloud (Stage 0)

Stage 0 is Terraform that **creates machines**. Stage 1 and Stage 2 both assume a host already exists; stage 0 is what produces one in a cloud account and attaches it to the tailnet so [Stage 1](../stage1/index.md) can reach it.

It is entirely optional and is a separate Terraform root you run on its own. A LAN-only cluster never runs it, and nothing in stage 1 or stage 2 depends on it.

## What it produces

| Layer | Component |
|---|---|
| Quota ceiling | A compartment quota capping the account at the free tier allowance. The compartment itself is created by hand during [account setup](oci-freetier.md#account-setup), not by Terraform |
| Network | Provider networking with **no inbound rule anywhere** by default. Egress only, unless `stage0_ssh_ingress_cidrs` opts TCP/22 in |
| Machine | One free tier instance per node you declare |
| Host firewall | Host rules permitting SSH over the tailnet interface, plus any `stage0_ssh_ingress_cidrs` sources |
| Transport | The node joined to your tailnet as `tag:k8s-node`, reachable on its `100.x` address |
| Handoff | A `worker_hosts_json` entry per node. Terraform cannot know the tailnet address, so you add `node_ip` by hand before Stage 1 joins the node |

It does **not** produce a control plane. A stage 0 node is a worker added to a cluster that already exists.

The concrete shapes, images and free tier ceiling are provider-specific: [Oracle Cloud free tier](oci-freetier.md).

## Where to go next

| I want to | Read |
|---|---|
| Understand what a cloud node is and how it reaches the cluster | [Cloud architecture](architecture.md) |
| Set up an Oracle account for the first time | [Account setup](oci-freetier.md#account-setup) |
| Know what the module creates, and the Always Free limits | [Oracle Cloud free tier](oci-freetier.md) |
| Actually add a node to my cluster, start to finish | [Oracle free tier worker](../operations/oracle-free-tier-worker.md) |
| Know which secrets to set | [Bitwarden secrets](../operations/bitwarden-secrets.md) |
| Look up a command | [Tasks](../reference/tasks.md) |

## Providers

Today one provider module exists: [Oracle Cloud free tier](oci-freetier.md), Oracle Cloud Always Free. The module is named `oci-freetier` rather than `oci` so that free tier is explicit and a future paid OCI module never collides with it.

Everything provider-agnostic lives in [Cloud architecture](architecture.md); everything Oracle-specific, including the console walkthrough, lives on the provider page. Adding another provider is a directory under `stage0/` and a few wiring points, described in [Extending Stage 0](architecture.md#extending-stage-0).

## First time here

Read [Cloud architecture](architecture.md), then follow [Oracle free tier worker](../operations/oracle-free-tier-worker.md). That runbook is the ordered path and links out to everything else at the point you need it.
