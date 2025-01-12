# **Secure User Provisioning for Grafana using Helm, Kubernetes, and Vault**

This repository contains a secure solution to automate the provisioning of Grafana users with predefined roles. The solution uses Kubernetes, Helm, and HashiCorp Vault to ensure sensitive data like user credentials are securely managed.

---

## **Solution Overview**

### **Key Features**

1. **Security First**:  
   * HashiCorp Vault securely stores sensitive user credentials.  
   * Kubernetes Secrets and ConfigMaps are used for secure data handling.  
   * HTTPS communication ensures secure API interactions.  
2. **Scalability**:  
   * Dynamically provision users via Helm and an Init Container.  
   * Easily scale to large numbers of users by managing configurations in Vault.  
3. **Flexibility**:  
   * Supports role-based access for users (`Viewer`, `Editor`, `Admin`).  
   * Dynamically updates or provisions new users by modifying Vault data.

---

## **How It Works**

1. **User Data Storage**:  
   * Sensitive data (e.g., passwords) is stored in HashiCorp Vault.  
   * Non-sensitive data (e.g., usernames, roles) is stored in Kubernetes ConfigMaps.  
2. **Init Container**:  
   * An Init Container fetches user credentials from Vault and provisions users via the Grafana REST API.  
3. **Helm Chart**:  
   * A Helm chart is used to deploy Grafana with the Init Container and Vault integration.  
4. **HTTPS Communication**:  
   * Grafana is exposed over a secured Ingress using TLS.

---

## **Repository Structure**

.
├── manifests/            # Kubernetes manifests
│   ├── configmap.yaml    # ConfigMap for environment variables
│   ├── secret.yaml       # Secret for sensitive data like tokens
│   ├── ingress.yaml      # Ingress for Grafana (optional)
│   ├── rbac.yaml         # RBAC for Vault (optional)
├── scripts/              # Python script for user provisioning
│   └── create_users.py
├── README.md             # Documentation
├── vault/                # Vault setup scripts and policies
└── examples/             # Example configurations
    ├── values.yaml       # Example custom values for Grafana Helm chart
    └── .env              # Example environment variables for the Python script

---

## **Deployment Instructions**

### **Prerequisites**

1. Kubernetes cluster.  
2. Helm installed locally.  
3. HashiCorp Vault deployed and integrated with Kubernetes.  
4. TLS certificates for Grafana (e.g., via cert-manager).
5. Python 3.8 or newer installed.
6. jq: A lightweight JSON processor for parsing API responses. sudo apt-get install jq 


---

### **Step 1: Setup Vault**

Deploy Vault and enable the KV secrets engine:  
`vault secrets enable -path=secret kv`

1. 

Store user credentials in Vault:  
`vault kv put secret/grafana/users \`  
  `admin_token="your-admin-api-token" \`  
  `users='[`  
    `{"username": "viewer1", "password": "securepassword1", "role": "Viewer"},`  
    `{"username": "editor1", "password": "securepassword2", "role": "Editor"}`  
  `]'`

2. 

Create a policy to allow access to user data:  
`path "secret/data/grafana/users" {`  
  `capabilities = ["read"]`  
`}`

3.   
4. Bind the policy to a Kubernetes role.

---

### **Step 2: Deploy Grafana with Helm**

Clone this repository:  
`git clone https://github.com/your-repo/grafana-user-provisioning.git`  
`cd grafana-user-provisioning`

1. 

Update `values.yaml` with your Grafana and Vault configurations:  
`grafana:`  
  `ingress:`  
    `enabled: true`  
    `hosts:`  
      `- grafana.local`  
    `tls:`  
      `- secretName: grafana-tls`  
        `hosts:`  
          `- grafana.local`

`vault:`  
  `secretPath: "secret/data/grafana/users"`  
  `role: "grafana-user-provisioner"`

2. 

Install the Helm chart:  
`helm install grafana charts/grafana`

3. 

---

### **Step 3: Verify User Provisioning**

Confirm Grafana is running:  
`kubectl get pods -n <namespace>`

1.   
2. Access Grafana at `https://grafana.local`.  
3. Log in with the provisioned users:  
   * Username: `viewer1`  
   * Password: `securepassword1`

---

## **Scaling to 50+ Users**

Add new users to Vault:  
`vault kv put secret/grafana/users \`  
  `users='[`  
    `{"username": "viewer1", "password": "securepassword1", "role": "Viewer"},`  
    `{"username": "editor1", "password": "securepassword2", "role": "Editor"},`  
    `{"username": "viewer2", "password": "securepassword3", "role": "Viewer"}`  
  `]'`

1. 

Update the Helm release:  
`helm upgrade grafana charts/grafana`

2. 

---

## **Security Best Practices**

1. **Use Vault for Password Management**:  
   * Avoid hardcoding sensitive data in Helm or Kubernetes.  
2. **RBAC Policies**:  
   * Ensure only authorized Pods can access Vault secrets.  
3. **TLS Encryption**:  
   * Always expose Grafana over HTTPS.

---

## **Future Improvements**

1. Integrate with SSO or Active Directory for user management.  
2. Automate Vault setup and policy binding.  
3. Use dynamic secrets in Vault for Grafana API tokens.

---

