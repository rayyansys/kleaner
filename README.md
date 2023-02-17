# Kleaner
*Kleaner - Container Registry Cleaner for Kubernetes*

Kleaner is a script that cleans up a Container Registry (currently Azure only) by deleting
images that are not used by any Kubernetes resources. It does this by getting a list of images
in the cluster and then deleting all images in the Container Registry that are not in the list.
Additionally, the deleted images must be older than the specified time. This is to prevent
deleting images that are release candidates. It also deletes any repo that ends with `/cache`.

## Usage
### Prerequisites
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) with read access to the Kubernetes cluster
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
with write access to the Container Registry

```bash
./kleaner.sh REGISTRY <ONLY_OLDER_THAN>
```

### Example
```bash
./kleaner.sh myregistry 7d
```

## Caveats
- The `date` command in the script only works on macOS.

## Disclaimer
Kleaner is not responsible for any damage caused by using this script.
Kleaner is provided as-is, without warranty of any kind, express or implied.
Use at your own risk.

Kleaner is written by [Hossam Hammady](https://github.com/hammady)
and is licensed under the [MIT License](LICENSE).
