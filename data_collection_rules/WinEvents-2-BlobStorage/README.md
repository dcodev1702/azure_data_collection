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

![image](https://github.com/user-attachments/assets/499e80fc-df5b-4b78-8ebf-41ab9d34e4b4)
## ADX EXTERNAL TABLE via ADLSv2 CONFIGURATION
1. Map ADLSv2 blob storage to ADX as an external table via a user assigned identity (UAI) -> map_uai_2_adx.json. </br>
   - Windows Events pulled from an Azure VM associated to a DCR that sends Windows Events directly to an ADLSv2 Blob container. </br>
   - The ADLSv2 blob container is mapped to ADX as an external table via a user assigned identity. </br>
   
```sql
// 2. GRANT PERMISSIONS TO THE USER MANAGED IDENTITY (OBJ ID) TO USE EXTERNAL TABLES
.alter-merge cluster policy managed_identity ```[
    {
        "ObjectId": "70c71c41-cc48-4b73-89e7-69ff6760d5aa",
        "AllowedUsages": "ExternalTable"
    }
]```
```
```sql
// 3: Create an external data source pointing to your storage account
let options = dynamic({
  'StorageContainers': [
    h@'https://datawinevents1799.blob.core.windows.net/secwineventsblob/i=56cc5340e30806d24a8691cb02ee613f/y=2025/m=04/d=06/h=03/m=00;impersonate'
  ],
  'fileExtension': '.json',
  'kind': 'storage',
  'partition': '(MinuteBin:datetime = bin(time:datetime, 1m))',
  'pathformat': '("i=[0-9a-f]{32}/" datetime_pattern("y={yyyy}/m={MM}/d={dd}/h={hh}/m={mm}",MinuteBin))',
  'dataformat': 'json',
  'mode': 'all'
});
evaluate infer_storage_schema(options) //result = records:dynamic
```
```sql
// 4: Create external table and map to blob storage via a user assigned identity
.create-or-alter external table WinEventsEXT (
  TimeGenerated: datetime,
  PublisherId: string,
  TimeCreated: datetime,
  PublisherName: string,
  Channel: string,
  LoggingComputer: string,
  EventID: string,
  EventCategory: string,
  EventLevel: string,
  UserName: string,
  RawXml: string,
  EventDescription: string,
  RenderingInfo: string,
  EventRecordId: string,
  Keywords: string
)
kind=storage
partition by (StreamId:string, IngestTime:datetime)
pathformat = ("i=" StreamId "/" datetime_pattern('y={yyyy}/m={MM}/d={dd}/h={HH}/m={mm}',IngestTime))
dataformat = multijson //required for json arrays (e.g. records[])
(
  h@'https://datawinevents1799.blob.core.windows.net/secwineventsblob;managed_identity=70c71c41-cc48-4b73-89e7-69ff6760d5aa'
)
with (filesPreview = true, fileExtension = '.json')
```
```sql
// 5: Create a map to the external WinEventsEXT table (e.g {Column: TimeGenerated -> "Properties":{"Path":"$.records[0].time"}})
.create-or-alter external table WinEventsEXT mapping "Mapping1" '[{"Column":"TimeGenerated","Properties":{"Path":"$.records[0].time"}},{"Column":"PublisherId","Properties":{"Path":"$.records[0].PublisherId"}},{"Column":"TimeCreated","Properties":{"Path":"$.records[0].TimeCreated"}},{"Column":"PublisherName","Properties":{"Path":"$.records[0].PublisherName"}},{"Column":"Channel","Properties":{"Path":"$.records[0].Channel"}},{"Column":"LoggingComputer","Properties":{"Path":"$.records[0].LoggingComputer"}},{"Column":"EventID","Properties":{"Path":"$.records[0].EventNumber"}},{"Column":"EventCategory","Properties":{"Path":"$.records[0].EventCategory"}},{"Column":"EventLevel","Properties":{"Path":"$.records[0].EventLevel"}},{"Column":"UserName","Properties":{"Path":"$.records[0].UserName"}},{"Column":"RawXml","Properties":{"Path":"$.records[0].RawXml"}},{"Column":"EventDescription","Properties":{"Path":"$.records[0].EventDescription"}},{"Column":"RenderingInfo","Properties":{"Path":"$.records[0].RenderingInfo"}},{"Column":"EventRecordId","Properties":{"Path":"$.records[0].EventRecordId"}},{"Column":"Keywords","Properties":{"Path":"$.records[0].Keywords"}}]'
```
```sql
// 6: Query the external table!
external_table('WinEventsEXT')
```
```sql
// THIS WILL DROP THE EXTERNAL TABLE AND IT'S MAPPING
.drop external table WinEventsEXT

.show external table WinEventsEXT mappings 

.drop external table WinEventsEXT mapping "Mapping1"
```
