# WIP AI-Q Agent for Enterprise Research Helm Chart

*** This is work in progress!!!! ***

This Helm chart deploys the [Nvidia AI-Q Agent for Enterprise Research](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant) and its associated services on HPE PCAI environments.

# Demo Video
In Progress

## Prerequisites

1. Access to an a PCAI cluster
2. Administrative privileges to import custom frameworks
3. NGC API key (to access container images)
4. Enterprise RAG Blueprint deployed (insert link here)
5. Deploy a Llama 3.x Instruct Model via MLIS, per default they expect Llama 3.3 70B instruct, but works with llama 3.1 8b as well.

## Preparation
- Setup required environment variables
    ```
    export NAMESPACE='aira'
    export NGC_API_KEY=<ngc-api-key-to-pull-images>
    export NVIDIA_API_KEY=<nvidia-api-key-to-use-nvidia-api>
    ```

- Create namespace (if not already created)
    ```
    kubectl create namespace $NAMESPACE
    ```
- Create secrets
    ```
    kubectl create secret docker-registry ngc-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_API_KEY -n $NAMESPACE
    kubectl create secret generic ngc-api --from-literal=NGC_API_KEY=$NVIDIA_API_KEY --from-literal=NGC_CLI_API_KEY=$NVIDIA_API_KEY -n $NAMESPACE
    ```
- run load-files.yaml (if you have been using the recommended namespaces for rag blueprint and this you don't need to adapt anything, if you decided for a different one, you might need to adapt the namespace (line 5) and the namespaces fo the rag services (line 17, line 21)). Once you've done the adpations run it with kubectl apply -f load-files.yaml
Bring some time for this step! It's two collections with in total 174 PDFs so it takes it's time to upload them.In the meanwhile you can proceed with importing the ai-q framework. You will need to wait until this job is finished in order to use the Financial or Biomedical example data set. 

## Configuration

1. **Import as Custom Framework**:
   Follow the steps in the [HPE documentation for importing applications as custom frameworks](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html):

   a. Log in to the HPE AI Essentials web interface.
   
   b. Click the **Tools & Frameworks** icon on the left navigation bar.
   
   c. Click **+ Import Framework**. Navigate through each step within the Import Framework wizard:

       Framework Details: 
        Set the following boxes on the Framework Details step:
        Framework Name: AI-Q Agent for Enterprise Research

        Version: Use the version number in the tgz file name (1.2.0)
        Description: NVIDIA AI-Q 

        Category: Select Data Science.

        Framework Icon: Click Select File and select the icon you want to use.
        
        Helm Chart: Choose the packaged chart file (.tgz) in this directory.
        
        Namespace: aira
        Release Name: of your choice, for example ai-q
        
    
    
**Framework Values:**
 Configure the override values file of your application by using the Helm Values (YAML) box. You will need to doublecheck the services referring to the ones deployed with your Enterprise RAG blueprint. To identify those sections search for "nv-nvidia-blueprint-rag". If you deployed your Enterprise RAG blueprint in the namespace nv-nvidia-blueprint-rag and made no changes to the services names you can leave them as is.

 You will need to provide the endpoint url and API Key for your via mlis deployed Llama instruct model.

* `<REQUIRED: ADD LLM MODEL NAME e.g. meta/llama-3.1-8b-instruct>` Should be replaced with the name of the model that you're using.
* `<OPTIONAL: ADD MLIS ENDPOINT/v1, or remove line if using NVIDIA Endpoint>` should be replaced with your MLIS model endpoint (without the `/v1`). Remove this name/value lines if you're using the Nvidia API endpoints
* `<OPTIONAL: ADD MLIS API KEY if using MLIS Endpoint>` should be replaced with your token to access the MLIS model endpoint. Remove this name/value lines if you're using the Nvidia API endpoints


## Additional Notes

- This chart is designed specifically for the AI-Q Agent for Enterprise Research deployment within HPE environments.

For more information on managing applications in HPE AI Essentials, refer to the [official documentation](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html).
