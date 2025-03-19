### Data Collection Endpoint & Rule creation via ARM Template Deployment (Azure UI)
---------------------------------------
- DCR's of Kind: Direct DO NOT REQUIRE A DCE! </br>
   *You have to select the latest API: 2023-03-11 to see the LogIngestion REST API Endpoint (Direct: Endpoint -> logIngestion) </br>
  ![image](https://github.com/user-attachments/assets/995dab2d-1fbc-4337-a9b5-ed9425cd4e69)

- [Data Stream](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview#endpoint) names within a DCR matter when it comes to sending data via REST API
  ![image](https://github.com/user-attachments/assets/a70122bf-94d3-47f0-9b78-ce59640fc623)

- [DCE / DCR ARM Deployment Tutorial](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dce) </br>

### Edit Data Collection Rules in place using ARM Deployment (Azure UI)
---------------------------------------
- [Edit Data Collection Rules via ARM Template](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-create-edit?tabs=cli#strategies-to-edit-and-test-a-dcr)
