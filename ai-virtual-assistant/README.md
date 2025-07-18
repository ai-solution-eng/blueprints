# AI Virtual Assistant Helm Chart

This Helm chart deploys the [Nvidia AI Virtual Assistant](https://github.com/NVIDIA-AI-Blueprints/ai-virtual-assistant) and its associated services on HPE PCAI environments.

# Demo Video
[![AI-virtual-assistant-demo-video](aiva-logo.png)](https://www.youtube.com/watch?v=CkfxdU_EK5M)

## Prerequisites

1. Access to an a PCAI cluster
2. Administrative privileges to import custom frameworks
3. NGC API key (to access container images)

### LLM Configuration

If you want to use the Nvidia public API, you'll need to have an api key for it.
If you're going to use an MLIS-provided model (meta/llama-3.1-8b-instruct recommended), you'll need the endpoint URL as well as an access token for the model.


## Configuration

1. **Import as Custom Framework**:
   Follow the steps in the [HPE documentation for importing applications as custom frameworks](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html):

   a. Log in to the HPE AI Essentials web interface.
   
   b. Click the **Tools & Frameworks** icon on the left navigation bar.
   
   c. Click **+ Import Framework**. Navigate through each step within the Import Framework wizard:

       Framework Details: 
        Set the following boxes on the Framework Details step:
        Framework Name: AIVA

        Version: Use the version number in the tgz file name (1.2.0)
        Description: NVIDIA AIVA 

        Category: Select Data Science.

        Framework Icon: Click Select File and select the icon you want to use.
        
        Helm Chart: Choose the packaged chart file (.tgz) in this directory.
        
        Namespace: aiva
        Release Name: aiva
        
    
    
**Framework Values:**
 Configure the override values file of your application by using the Helm Values (YAML) box. This is where you will need to supply the items listed above (NGC key, MLIS endpoint and token, etc):

* `<REQUIRED: ADD NGC KEY>` Should be replaced with your NGC API key that has access to the NIMs in this blueprint
* `<REQUIRED: ADD LLM MODEL NAME e.g. meta/llama-3.1-8b-instruct>` Should be replaced with the name of the model that you're using.
* `<OPTIONAL: ADD MLIS ENDPOINT/v1, or remove line if using NVIDIA Endpoint>` should be replaced with your MLIS model endpoint (without the `/v1`). Remove this name/value lines if you're using the Nvidia API endpoints
* `<OPTIONAL: ADD MLIS API KEY if using MLIS Endpoint>` should be replaced with your token to access the MLIS model endpoint. Remove this name/value lines if you're using the Nvidia API endpoints
* `<OPTIONAL: ADD NVIDIA API KEY if using NVIDIA Endpoint>` should be replaced wiht your Nvidia API key (not your NGC key) if you're using the API endpoints. There are 4 locations in the values you need to update.


## Additional Notes

- This chart is designed specifically for the AI Virtual Assistant deployment within HPE environments.

For more information on managing applications in HPE AI Essentials, refer to the [official documentation](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html).
