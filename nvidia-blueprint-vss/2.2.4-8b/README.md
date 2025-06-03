
# Nvidia Video Search and Summarization Agent Helm Chart with 8b model
This Helm chart deploys the Nvidia Video Search and Summarization Agent Blueprint https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization and its associated services on HPE PCAI environments in an adpated variation using a local 8b Llama model instead of 70b.

## Prerequisites
1. Access to an a PCAI cluster
2. Administrative privileges to import custom frameworks
3. NGC API key (to access container images)
4. NVIDIA API key (to access NVIDIA API endpoints)
5. Create the following two secrets filling in your NGC API key and NVIDIA API key in the namespace of your choice, e.g.. You might need to create the namespace first (```kubectl create namespace vss```):
    ```kubectl create secret generic ngc-secret --from-literal=ngc-api-key=YOUR_NGC_API_KEY -n vss```
    
    ```kubectl create secret generic nvidia-api-key-secret --from-literal=NVIDIA_API_KEY=YOUR_NVIDIA_API_KEY -n vss```


## Configuration
1. **Import as Custom Framework**: 
Follow the steps in the [HPE documentation for importing applications as custom frameworks](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html):

a. Log in to the HPE AI Essentials web interface.

b. Click the **Tools & Frameworks** icon on the left navigation bar.

c. Click **+ Import Framework**. Navigate through each step within the Import Framework wizard:

    Framework Details: 
        Set the following boxes on the Framework Details step:
        Framework Name: of your choice, for example NVIDIA VSS.

        Description: of your choice, for example NVIDIA VSS.

        Category: Select Data Science.

        Framework Icon: Click Select File and select the icon you want to use, e.g. the .jpg file in the parent folder.
        
        Helm Chart: Choose the packaged chart file nvidia-blueprint-2.2.4-8b.tgz in the parent folder.
        
        Namespace: where you created your secrets in, for example vss

## Additional Notes
The cert-copy.yaml in the subfolder templates/ezua is only required for environments with AIE 1.6 using self-signed certificates. 
This chart is designed specifically for the Nvidia Video Search and Summarization Agent deployment within HPE environments.
For more information on managing applications in HPE AI Essentials, refer to the [official documentation](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html).
