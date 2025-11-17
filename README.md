# Kubernetes API Workshop - Getting Started

Welcome to the Kubernetes API Workshop! This guide will help you get set up and ready to explore the power of the Kubernetes API.

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] **Kubernetes Cluster** running (minikube, kind, Docker Desktop, or cloud-based)
- [ ] **kubectl** installed and configured
- [ ] **Java 17+** installed (for Java examples)
- [ ] **Maven 3.6+** installed (for Java examples)
- [ ] **Python 3.8+** installed (for Python examples)
- [ ] **pip** installed (for Python examples)
- [ ] Code editor (VS Code, IntelliJ IDEA, PyCharm, etc.)

## 🚀 Quick Setup

### Step 1: Verify Kubernetes Cluster

```bash
# Check if kubectl is installed
kubectl version --client

# Verify cluster access
kubectl cluster-info

# Check nodes
kubectl get nodes

# Cluster setup
```

### Set Up Python Environment

```bash
# Navigate to Python examples
cd python-examples

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```