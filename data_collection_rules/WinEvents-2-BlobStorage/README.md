Provisioning Order:
-------------------
1. User Assigned Identity
   - Associate UAI to Storage Account with [Storage Blob Data Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
   - Associate UAI with Virtual Machine
   - Storage Blob Data Contributor Role: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
3. Storage Account
   - Blob (ALDSv2) (private)
     - Hot Tier / Block Blob
   - Files (private)
   - Entra ID Auth (default)
   - Anonymous Access Disabled
4. Data Collection Rule (AgenDirectToStore)
   - Associate Storage Account with DCR as destination
5. Associate DCR with VM
6. Provision AzureMonitorAgent (AMA) extension on VM via User Assigned Identity (UAI)


[Setup](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/send-event-hubs-storage?tabs=windows%2Cwindows-1)

[Windows Events to Storage](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-samples)

7. Map ADLSv2 blob storage to ADX as an external table via a user assigned identity (UAI) -> map_uai_2_adx.json. </br>
   - Windows Events pulled from an Azure VM associated to a DCR that sends Windows Events directly to an ADLSv2 Blob container. </br>
   - The ADLSv2 blob container is mapped to ADX as an external table via a user assigned identity. </br>
![image](https://github.com/user-attachments/assets/4e071a55-c92d-4b64-9946-b6a19efaae28)


