registry=$1
only_older_than=${2:-30d}

function print_banner() {
    echo
    echo "Kleaner - Container Registry Cleaner for Kubernetes"
    echo
    echo "Kleaner is a script that cleans up a Container Registry (currently Azure only) by deleting images that are not used by any Kubernetes resources."
    echo "It does this by getting a list of images in the cluster and then deleting all images in the Container Registry that are not in the list."
    echo "Additionally, the deleted images must be older than the specified time. This is to prevent deleting images that are release candidates."
    echo "It also deletes any repo that ends with /cache."
    echo
    echo "Kleaner is not responsible for any damage caused by using this script."
    echo
    echo "Kleaner is provided as-is, without warranty of any kind, express or implied."
    echo "Use at your own risk."
    echo
    echo "Kleaner is open source and available at https://github.com/rayyansys/kleaner"
    echo
    echo "Kleaner is written by Hossam Hammady (github@hammady.net)"
    echo
}

function print_usage() {
    echo "Usage: kleaner.sh <Azure Container Registry name> [<only_older_than (default: 30d)>]"
    echo "Example: kleaner.sh myregistry 30d"
}

print_banner

if [ -z "$registry" ]; then
    echo "Error: Azure Container Registry name is required"
    print_usage
    exit 1
fi

function get_images() {
    # Run the following with access to the cluster
    # get list of all images in the cluster
    deployments=`kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.template.spec.containers[*].image}{end}{"\n"}'`
    statefulsets=`kubectl get statefulsets --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.template.spec.containers[*].image}{end}{"\n"}'`
    cronjobs=`kubectl get cronjobs --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.jobTemplate.spec.template.spec.containers[*].image}{end}{"\n"}'`
    jobs=`kubectl get jobs --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.template.spec.containers[*].image}{end}{"\n"}'`
    daemonsets=`kubectl get daemonsets --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.template.spec.containers[*].image}{end}{"\n"}'`
    replicasets=`kubectl get replicasets --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.template.spec.containers[*].image}{end}{"\n"}'`
    replicationcontrollers=`kubectl get replicationcontrollers --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.template.spec.containers[*].image}{end}{"\n"}'`
    pods=`kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{"\n"}{.spec.containers[*].image}{end}{"\n"}'`

    registry_host=$registry.azurecr.io
    echo $deployments $statefulsets $cronjobs $jobs $daemonsets $replicasets $replicationcontrollers $pods | tr ' ' '\n' | grep "$registry_host" | sort | uniq
}

function get_registry_usage() {
    # print usage of the Container Registry
    echo "Getting Azure Container Registry usage..."
    az acr show-usage -n $registry --output tsv --query "value[?name=='Size'].currentValue | [0]" | awk '{print "Current usage: " $1/1024/1024/1024 " GB"}'
}

function count_args() {
    echo $#
}

function clean_registry() {
    # Run this with access to the Container Registry using az cli
    # iterate through all repos in the Container Registry and get their tags
    images=$1
    echo "Getting list of repos in the Azure Container Registry: $registry..."
    repos=`az acr repository list --name $registry --output tsv`
    echo "Found $(count_args $repos) repos in the Azure Container Registry"
    for repo in $repos; do
        # if the repo name ends with /cache, delete the whole repo
        if [[ $repo == *"/cache" ]]; then
            echo "Repo $repo is a cache, deleting it..."
            az acr repository delete --name $registry --repository $repo --yes --only-show-errors
            continue
        fi
        echo "Getting list of tags for $repo older than $only_older_than..."
        tags=`az acr repository show-tags --name $registry --repository $repo --detail --orderby time_asc --query "[?createdTime<'$(date -v -$only_older_than -u +"%Y-%m-%dT%H:%M:%SZ")'].name" -o tsv`
        echo "Found $(count_args $tags) tags for $repo older than $only_older_than"
        for tag in $tags; do
            image="$repo:$tag"
            if [[ $images == *"$image"* ]]; then
                echo "$image found, skipping"
            else
                echo "$image not found, deleting"
                az acr repository delete --name $registry --image $image --yes --only-show-errors
            fi
        done
    done
}

echo "Getting list of images in the cluster..."
images=$(get_images)
echo "Found $(count_args $images) images in the cluster"

echo "Azure Container Registry usage before cleaning: $(get_registry_usage)"

echo "Cleaning Azure Container Registry..."
clean_registry "$images"

echo "Azure Container Registry usage after cleaning: $(get_registry_usage)"
