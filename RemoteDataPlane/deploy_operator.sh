OPERATOR_REGISTRY="icr.io/cpopen"
OPERATOR_DIGEST=""
namespace=""
kubernetesCLI="oc"

version=""

verify_args() {
  # check if oc cli available
  which oc > /dev/null
  if [ $? -ne 0 ]; then
    echo "Unable to locate oc cli"
    exit 3
  fi
  
  # check if the specified namespace exists and is a management namespace
  oc get namespace $namespace &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Namespace $namespace not found."
    exit 3
  fi
  oc -n $namespace get cm physical-location-info-cm &> /dev/null
  if [ $? -ne 0 ]; then
    echo "The specified namespace $namespace is not a management namespace. Unable to locate the configmap physical-location-info-cm."
    exit 3
  fi
}

create_analyticsengine_crd() {
  cat <<EOF | $kubernetesCLI -n $namespace apply ${dryRun} -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: analyticsenginedataplanes.ae.cpd.ibm.com
spec:
  group: ae.cpd.ibm.com
  names:
    kind: AnalyticsEngineDataplane
    listKind: AnalyticsEngineDataplaneList
    plural: analyticsenginedataplanes
    singular: analyticsenginedataplane
  scope: Namespaced
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        description: AnalyticsEngineDataplane is the Schema for the analyticsenginedataplanes API
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            description: Spec defines the desired state of AnalyticsEngineDataplane
            type: object
            x-kubernetes-preserve-unknown-fields: true
          status:
            description: Status defines the observed state of AnalyticsEngineDataplane
            type: object
            properties:
              version:
                description: Version of the AnalyticsEngineDataplane
                type: string
            x-kubernetes-preserve-unknown-fields: true
        type: object
    served: true
    storage: true
    subresources:
      status: {}
EOF
}

create_service_account() {
  #sed <"${serviceAccountFile}" "s#NAMESPACE_REPLACE#${namespace}#g" | $kubernetesCLI apply ${dryRun} -f -
  cat <<EOF | $kubernetesCLI -n $namespace apply ${dryRun} -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/name: analyticsenginedataplane
    app.kubernetes.io/managed-by: kustomize
  name: zen-norbac-sa
  namespace: $namespace
EOF
}

create_role() {
  cat <<EOF | $kubernetesCLI -n $namespace apply ${dryRun} -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ibm-cpd-aedataplane-operator-cluster-role
rules:
  ##
  ## Base operator rules
  ##
  - apiGroups:
      - ""
    resources:
      - secrets
      - pods
      - pods/exec
      - pods/log
      - configmaps
      - cronjobs
      - jobs
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  - apiGroups:
      - apps
    resources:
      - deployments
      - daemonsets
      - replicasets
      - statefulsets
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  - apiGroups:
      - batch
    resources:
      - jobs
      - cronjobs
    verbs:
      - create
      - delete
      - patch
      - get
      - list
      - update
      - watch
  ##
  ## Rules for ae.cpd.ibm.com/v1, Kind: AnalyticsEngineDataplane
  ##
  - apiGroups:
      - ae.cpd.ibm.com
    resources:
      - analyticsenginedataplanes
      - analyticsenginedataplanes/status
      - analyticsenginedataplanes/finalizers
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
#+kubebuilder:scaffold:rules
  - apiGroups:
      - zen.cpd.ibm.com
    resources:
      - zenextensions
      - zenextensions/status
      - zenextensions/finalizers
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
EOF
}

create_role_binding() {
  cat <<EOF | $kubernetesCLI -n $namespace apply ${dryRun} -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/name: analyticsenginedataplane
    app.kubernetes.io/managed-by: kustomize
  name: ibm-cpd-aedataplane-operator-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ibm-cpd-aedataplane-operator-cluster-role
subjects:
- kind: ServiceAccount
  name: zen-norbac-sa
  namespace: $namespace
EOF
}

get_plnameid_from_cm() {
    config_map_json=$(oc get cm physical-location-info-cm -n "$namespace" -o json)
    if [ $? -ne 0 ]; then
        echo "Failed to get ConfigMap physical-location-info-cm in namespace $namespace."
        return 1
    fi

    # Use jq to parse the JSON and extract the desired values
    PHYSICAL_LOCATION_NAME=$(echo "$config_map_json" | jq -r '.data.PHYSICAL_LOCATION_NAME')
    PHYSICAL_LOCATION_ID=$(echo "$config_map_json" | jq -r '.data.PHYSICAL_LOCATION_ID')

    echo "Physical Location Name: $PHYSICAL_LOCATION_NAME"
    echo "Physical Location ID: $PHYSICAL_LOCATION_ID"
}

create_operator_deployment() {
  cat <<EOF | $kubernetesCLI -n $namespace apply ${dryRun} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ibm-cpd-aedataplane-operator
  namespace: $namespace
  labels:
    control-plane: controller-manager
    app.kubernetes.io/name: analyticsenginedataplane
    app.kubernetes.io/managed-by: kustomize
    icpdsupport/physicalLocationId: $PHYSICAL_LOCATION_ID
    icpdsupport/physicalLocationName: $PHYSICAL_LOCATION_NAME
spec:
  selector:
    matchLabels:
      control-plane: controller-manager
  replicas: 1
  template:
    metadata:
      annotations:
        kubectl.kubernetes.io/default-container: manager
      labels:
        control-plane: controller-manager
    spec:
      # TODO(user): Uncomment the following code to configure the nodeAffinity expression
      # according to the platforms which are supported by your solution.
      # It is considered best practice to support multiple architectures. You can
      # build your manager image using the makefile target docker-buildx.
      # affinity:
      #   nodeAffinity:
      #     requiredDuringSchedulingIgnoredDuringExecution:
      #       nodeSelectorTerms:
      #         - matchExpressions:
      #           - key: kubernetes.io/arch
      #             operator: In
      #             values:
      #               - amd64
      #               - arm64
      #               - ppc64le
      #               - s390x
      #           - key: kubernetes.io/os
      #             operator: In
      #             values:
      #               - linux
      securityContext:
        runAsNonRoot: true
        # TODO(user): For common cases that do not require escalating privileges
        # it is recommended to ensure that all your Pods/Containers are restrictive.
        # More info: https://kubernetes.io/docs/concepts/security/pod-security-standards/#restricted
        # Please uncomment the following code if your project does NOT have to work on old Kubernetes
        # versions < 1.19 or on vendors versions which do NOT support this field by default (i.e. Openshift < 4.11 ).
        # seccompProfile:
        #   type: RuntimeDefault
      containers:
      - args:
          - "--max-concurrent-reconciles"
          - "6"
        image: ${OPERATOR_REGISTRY}/ibm-cpd-analyticsengine-dataplane-operator${OPERATOR_DIGEST}
        name: manager
        env:
        - name: ANSIBLE_GATHERING
          value: explicit
        - name: WATCH_NAMESPACE
          value: $namespace
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - "ALL"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 6789
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 6789
          initialDelaySeconds: 5
          periodSeconds: 10
        # TODO(user): Configure the resources accordingly based on the project requirements.
        # More info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
        resources:
          limits:
            cpu: 500m
            memory: 768Mi
          requests:
            cpu: 10m
            memory: 256Mi
      serviceAccountName: zen-norbac-sa
      terminationGracePeriodSeconds: 10
EOF
}

create_main_operator() {
  cat <<EOF | $kubernetesCLI -n $namespace apply ${dryRun} -f -
apiVersion: ae.cpd.ibm.com/v1
kind: AnalyticsEngineDataplane
metadata:
  name: analyticsenginedataplane-sample
  namespace: $namespace
spec:
  version: "$version"
EOF
}

handle_badusage() {
    echo "Usage: $0 --namespace <namespace> --digest <digest> --version <vesrion>"
    exit 1
}

# Check for the correct number of parameters
if [[ "$#" -ne 6 ]]; then
    handle_badusage
fi

# Directly assign parameters based on expected positions
# if [[ "$1" == "--namespace" && "$3" == "--digest" ]]; then
#     namespace="$2"
#     OPERATOR_DIGEST="$4"
# else
#     echo "Error: Invalid parameters."
#     handle_badusage
# fi

if [[ "$1" != "--namespace" ]]; then
    echo "Error: Invalid first parameter."
    handle_badusage
    exit 1
fi

namespace="$2"

if [[ "$3" != "--digest" ]]; then
    echo "Error: Invalid second parameter."
    handle_badusage
    exit 1
fi

OPERATOR_DIGEST="@sha256:$4"

if [[ "$5" != "--version" ]]; then
    echo "Error: Invalid third parameter."
    handle_badusage
    exit 1
fi

version="$6"
echo "version: $version"

PHYSICAL_LOCATION_NAME=""
PHYSICAL_LOCATION_ID=""

verify_args
# check_version
create_analyticsengine_crd
create_service_account
create_role
create_role_binding
get_plnameid_from_cm
create_operator_deployment
create_main_operator
