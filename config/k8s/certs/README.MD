### 使用证书的组件如下：
etcd：使用 ca.pem kubernetes-key.pem kubernetes.pem 
kube-apiserver：使用 ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem
kubelet：使用 ca.pem
kube-proxy：使用 ca.pem kube-proxy-key.pem kube-proxy.pem
kubectl：使用 ca.pem admin-key.pem、admin.pem
kube-controller-manager：使用 ca-key.pem ca.pem kube-controller-manager-key.pem kube-controller-manager.pem
kube-scheduler: 使用 kube-scheduler-key.pem kube-scheduler.pem

### 证书详情

**CA证书**
ca-config.json 证书配置文件
字段说明：
signing：表示该证书可以签名其他证书；生成的ca.pem证书中 CA=TRUE；
server auth：表示client可以用该 CA 对server提供的证书进行验证；
client auth：表示server可以用该CA对client提供的证书进行验证；
expiry：过期时间

ca-csr.json 证书签名请求文件
字段说明：
“CN”：Common Name，kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)；浏览器使用该字段验证网站是否合法；
“O”：Organization，kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)

**kubernetes证书**
kubernetes-csr.json kubernetes证书签名请求文件 
如果 hosts 字段不为空则需要指定授权使用该证书的 IP 或域名列表。
由于该证书后续被 etcd 集群和 kubernetes master 集群使用，将etcd、master节点的IP都填上，同时还有service网络的首IP。(一般是 kube-apiserver 指定的 service-cluster-ip-range 网段的第一个IP，如 10.0.0.1)
三个etcd，三个master，以上物理节点的IP也可以更换为主机名。

**aggregator证书**
proxy-client-csr.json kube-aggregator证书签名请求文件 
说明：
这个是k8s在1.7的新特性，如果是1.16版本的可以不用添加，1.17以后要添加。这个参数的作用是Aggregation允许在不修改Kubernetes核心代码的同时扩展Kubernetes API（metrics-server资源使用监控）。

**admin证书**
admin-csr.json admin证书签名请求文件
说明：
后续 kube-apiserver 使用 RBAC 对客户端(如 kubelet、kube-proxy、Pod)请求进行授权；
kube-apiserver 预定义了一些 RBAC 使用的 RoleBindings，如 cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予了调用kube-apiserver 的所有 API的权限；
O指定该证书的 Group 为 system:masters，kubelet 使用该证书访问 kube-apiserver 时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 system:masters，所以被授予访问所有 API 的权限；
注：这个admin 证书，是将来生成管理员用的kube config 配置文件用的，现在我们一般建议使用RBAC 来对kubernetes 进行角色权限控制， kubernetes 将证书中的CN 字段 作为User， O 字段作为 Group

**kube-proxy证书**
kube-proxy-csr.json kube-proxy 证书签名请求文件 
说明：
CN 指定该证书的 User 为 system:kube-proxy；
kube-apiserver 预定义的 RoleBinding system:node-proxier 将User system:kube-proxy 与 Role system:node-proxier 绑定，该 Role 授予了调用 kube-apiserver Proxy 相关 API 的权限；
该证书只会被 kubectl 当做 client 证书使用，所以 hosts 字段为空 

**kube-controoler-manager证书**
kube-controller-manager-csr.json  kube-controoler-manager 证书签名请求文件 
说明：
hosts 列表包含所有 kube-controller-manager 节点 IP；
CN 为 system:kube-controller-manager、O 为 system:kube-controller-manager，kubernetes 内置的 ClusterRoleBindings system:kube-controller-manager 赋予 kube-controller-manager 工作所需的权限

**kube-scheduler证书**
kube-scheduler-csr.json kube-scheduler 证书签名请求文件
说明：
hosts 列表包含所有 kube-scheduler 节点 IP；
CN 为 system:kube-scheduler、O 为 system:kube-scheduler，kubernetes 内置的 ClusterRoleBindings system:kube-scheduler 将赋予 kube-scheduler 工作所需的权限。