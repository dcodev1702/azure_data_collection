### Data Collection Endpoint & Rule creation via ARM Template Deployment (Azure UI)
---------------------------------------
- [Stream Declarations](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-structure#input-streams) in a DCR HAVE TO MATCH the stream in your REST API call.  Not the Custom Log Table, the Stream! </br>
  ![image](https://github.com/user-attachments/assets/98c4cd7f-0100-4ce9-bcd0-e0f7addeee9a)

- Order of operations when it comes to Application Registration, Custom Log Tables, Data Collection Rules, etc
  ![image](https://github.com/user-attachments/assets/0f9a6ec0-7e79-4e65-ad75-f297be6c2318)


- DCR's of Kind: Direct DO NOT REQUIRE A DCE! </br>
   * Azure Monitor -> Data Collection Rules -> Your DCR. Select the latest API: 2023-03-11 to see the LogIngestion REST API Endpoint. </br>
   ![image](https://github.com/user-attachments/assets/d81ab64e-75c2-4601-87d0-4197143f9d2d)


- [Data Stream](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview#endpoint) names within a DCR matter when it comes to sending data via REST API </br>

  When sending telemetry via REST API, it's vitally important to ensure the STREAMS match!! (highlighted in red) </br>
  ![image](https://github.com/user-attachments/assets/3b8fb6f1-82a0-497c-8325-9fd686358999)



  ![image](https://github.com/user-attachments/assets/93814f84-d41b-4a05-9f52-28a28e1d0531)


- [DCE / DCR ARM Deployment Tutorial](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dce) </br>

### Edit Data Collection Rules in place using ARM Deployment (Azure UI)
---------------------------------------
- [Edit Data Collection Rules via ARM Template](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-create-edit?tabs=cli#strategies-to-edit-and-test-a-dcr)
