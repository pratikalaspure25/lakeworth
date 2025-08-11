import { OmniscriptBaseMixin } from "omnistudio/omniscriptBaseMixin";


public with sharing class PersonAccountLookupCtrl {
    @AuraEnabled(cacheable=true)
    public static List<Account> search(String objectApiName,
                                       String searchKey,
                                       List<String> displayFields,
                                       Integer limitSize) {

        // Default limit size if none is provided
        Integer lim = Math.min((limitSize == null ? 20 : limitSize), 50);
        
        // Escape the search term to prevent SOQL injection and format it for LIKE clause
        String term = '%' + (searchKey == null ? '' : String.escapeSingleQuotes(searchKey)) + '%';

        // Log the search term being used
        System.debug('Search term: ' + term);
        
        // Ensure only Account object is searched
        if (objectApiName != 'Account') {
            throw new AuraHandledException('Only Account (Person Account) is supported.');
        }

        // Build the field list (include Id and Name as mandatory fields)
        Set<String> base = new Set<String>{'Id','Name'};
        if (displayFields != null) base.addAll(displayFields);  // Add user-defined fields
        String fieldList = String.join(new List<String>(base), ',');

        // Construct the SOQL query string
        String soql = 
            'SELECT ' + fieldList +
            ' FROM Account' +
            ' WHERE IsPersonAccount = TRUE' +
            ' AND (Name LIKE :term OR FirstName LIKE :term OR LastName LIKE :term)' +  // Search condition
            ' ORDER BY Name' +
            ' LIMIT :lim';

        // Log the SOQL query being executed
        System.debug('Executing SOQL query: ' + soql);

        // Execute the query and return the results
        List<Account> result = Database.query(soql);

        // Log the results returned
        System.debug('Query Results: ' + result);
        
        return result;
    }
}



import { LightningElement, api, track } from "lwc";
import { OmniscriptBaseMixin } from "omnistudio/omniscriptBaseMixin";
import searchRecords from "@salesforce/apex/PersonAccountLookupCtrl.search";

export default class LookupObject extends OmniscriptBaseMixin(LightningElement) {
  @api objectApiName = "Account"; // Person Account live on Account
  @api label = "Select Person Account";

  @track searchResults = [];
  @track selectedRecord;
  @track isLoading = false;

  searchKey = "";

  // Debug: Log when the search key changes
  handleSearchKeyChange(event) {
    this.searchKey = event.target.value;
    console.log("Search key changed to:", this.searchKey); // Debugging

    // Only trigger search if there is something typed
    if (this.searchKey.length > 2) {
      this.searchRecords();
    } else {
      this.searchResults = [];
    }
  }

  // Call Apex to search records
  searchRecords() {
    this.isLoading = true;
    console.log('Calling Apex with searchKey:', this.searchKey); // Debugging

    searchRecords({
      objectApiName: this.objectApiName,
      searchKey: this.searchKey,
      displayFields: [
        "Name",
        "Salutation",
        "FirstName",
        "PersonMiddleName",
        "LastName",
        "PersonEmail",
        "PersonMobilePhone",
        "PersonBirthdate"
      ],
      limitSize: 5
    })
      .then((result) => {
        console.log('Apex returned:', result); // Debugging: Log Apex results
        this.searchResults = result;
      })
      .catch((error) => {
        console.error('Error in Apex call:', error); // Debugging: Log any errors
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Handle selection of record
  handleSelect(event) {
    const recordId = event.currentTarget.dataset.id;
    this.selectedRecord = this.searchResults.find(r => r.Id === recordId);
    console.log("Selected record:", this.selectedRecord); // Debugging: Log selected record

    this.searchResults = [];
    this.searchKey = this.selectedRecord.Name;

    // Prepare data to return to OmniScript
    const data = {
      PersonalInformation: {
        Salutation: this.selectedRecord.Salutation,
        FirstName: this.selectedRecord.FirstName,
        MiddleName: this.selectedRecord.PersonMiddleName,
        LastName: this.selectedRecord.LastName,
        Email: this.selectedRecord.PersonEmail,
        PhoneNumber: this.selectedRecord.PersonMobilePhone,
        DateOfBirth: this.selectedRecord.PersonBirthdate
      },
      personAccountId: this.selectedRecord.Id
    };
    this.omniApplyCallResp(data); // Return data to OmniScript
  }
}
<template>
    <div class="slds-form-element">
        <!-- This is the label you see -->
        <label class="slds-form-element__label">{label}</label>

        <div class="slds-form-element__control">
            <input
                type="text"
                class="slds-input"
                placeholder="Select party profile..."
                value={searchKey}
                oninput={handleSearchKeyChange}
            />
        </div>

        <!-- Debugging: Show if no results found -->
        <template if:true={searchResults}>
            <ul class="slds-listbox slds-listbox_vertical slds-scrollable">
                <template for:each={searchResults} for:item="record">
                    <li key={record.Id}
                        class="slds-listbox__item"
                        onclick={handleSelect}
                        data-id={record.Id}>
                        <div class="slds-listbox__option slds-listbox__option_plain">
                            {record.Name}
                        </div>
                    </li>
                </template>
            </ul>
        </template>

        <template if:true={searchResults.length == 0}>
            <div>No records found</div> <!-- Debugging: Display this if no records -->
        </template>
    </div>
</template>


<template>
    <div class="slds-form-element">
        <!-- This is the label you see -->
        <label class="slds-form-element__label">{label}</label>

        <div class="slds-form-element__control">
            <input
                type="text"
                class="slds-input"
                placeholder="Select party profile..."
                value={searchKey}
                oninput={handleSearchKeyChange}
            />
        </div>

        <template if:true={searchResults}>
            <ul class="slds-listbox slds-listbox_vertical slds-scrollable">
                <template for:each={searchResults} for:item="record">
                    <li key={record.Id}
                        class="slds-listbox__item"
                        onclick={handleSelect}
                        data-id={record.Id}>
                        <div class="slds-listbox__option slds-listbox__option_plain">
                            {record.Name}
                        </div>
                    </li>
                </template>
            </ul>
        </template>
    </div>
</template>

// lookupObject.js
import { LightningElement, api, track } from "lwc";
import { OmniscriptBaseMixin } from "omnistudio/omniscriptBaseMixin";
import searchRecords from "@salesforce/apex/PersonAccountLookupCtrl.search";

export default class LookupObject extends OmniscriptBaseMixin(LightningElement) {
  @api objectApiName = "Account";           // << Person Accounts live on Account
  @api label = "Select Person Account";

  @track searchResults = [];
  @track selectedRecord;
  @track isLoading = false;

  searchKey = "";

  handleSearchKeyChange(event) {
    this.searchKey = event.target.value;
    this.searchRecords();
  }

  searchRecords() {
    this.isLoading = true;
    searchRecords({
      objectApiName: this.objectApiName,
      searchKey: this.searchKey,
      // Person Account-friendly fields
      displayFields: [
        "Name",
        "Salutation",
        "FirstName",
        "PersonMiddleName",     // middle name on Person Account
        "LastName",
        "PersonEmail",
        "PersonMobilePhone",
        "PersonBirthdate"
      ],
      limitSize: 5
    })
      .then((result) => { this.searchResults = result; })
      .catch((e) => { console.error(e); })
      .finally(() => { this.isLoading = false; });
  }

  handleSelect(event) {
    const recordId = event.currentTarget.dataset.id;
    this.selectedRecord = this.searchResults.find(r => r.Id === recordId);
    this.searchResults = [];
    this.searchKey = this.selectedRecord.Name;

    // Map Person Account fields into your OmniScript JSON
    const data = {
      PersonalInformation: {
        Salutation: this.selectedRecord.Salutation,
        FirstName: this.selectedRecord.FirstName,
        MiddleName: this.selectedRecord.PersonMiddleName,
        LastName: this.selectedRecord.LastName,
        Email: this.selectedRecord.PersonEmail,
        PhoneNumber: this.selectedRecord.PersonMobilePhone,
        DateOfBirth: this.selectedRecord.PersonBirthdate
      },
      personAccountId: this.selectedRecord.Id
    };
    this.omniApplyCallResp(data);
  }
}


public with sharing class PersonAccountLookupCtrl {
    @AuraEnabled(cacheable=true)
    public static List<Account> search(String objectApiName,
                                       String searchKey,
                                       List<String> displayFields,
                                       Integer limitSize) {

        // safety defaults
        Integer lim = Math.min((limitSize == null ? 20 : limitSize), 50);
        String term = '%' + (searchKey == null ? '' : String.escapeSingleQuotes(searchKey)) + '%';

        // Only Account is supported here
        if (objectApiName != 'Account') {
            throw new AuraHandledException('Only Account (Person Account) is supported.');
        }

        // Build the field list (always include Id & Name)
        Set<String> base = new Set<String>{'Id','Name'};
        if (displayFields != null) base.addAll(displayFields);
        String fieldList = String.join(new List<String>(base), ',');

        String soql =
            'SELECT ' + fieldList +
            ' FROM Account' +
            ' WHERE IsPersonAccount = TRUE' +
            ' AND (Name LIKE :term OR FirstName LIKE :term OR LastName LIKE :term)' +
            ' ORDER BY Name' +
            ' LIMIT :lim';

        return Database.query(soql);
    }
}

public with sharing class PersonAccountLookupCtrl {
    @AuraEnabled(cacheable=true)
    public static List<Account> search(String objectApiName,
                                       String searchKey,
                                       List<String> displayFields,
                                       Integer limitSize) {

        // safety defaults
        Integer lim = Math.min((limitSize == null ? 20 : limitSize), 50);
        String term = '%' + (searchKey == null ? '' : String.escapeSingleQuotes(searchKey)) + '%';

        // Only Account is supported here
        if (objectApiName != 'Account') {
            throw new AuraHandledException('Only Account (Person Account) is supported.');
        }

        // Build the field list (always include Id & Name)
        Set<String> base = new Set<String>{'Id','Name'};
        if (displayFields != null) base.addAll(displayFields);
        String fieldList = String.join(new List<String>(base), ',');

        String soql =
            'SELECT ' + fieldList +
            ' FROM Account' +
            ' WHERE IsPersonAccount = TRUE' +
            ' AND (Name LIKE :term OR FirstName LIKE :term OR LastName LIKE :term)' +
            ' ORDER BY Name' +
            ' LIMIT :lim';

        return Database.query(soql);
    }
}


@api label = "Select Individual Relationship";



String endpointUrl = '/services/data/v58.0/actions/standard/initiateIdentityDocumentAnalysis';
String endpointUrl = '/services/data/v58.0/actions/standard/fetchIdentityDocumentAnalysisResult';


public class IdentificationSaverJob implements Queueable {
    private String rawJson;
    private Id     recordId;

    public IdentificationSaverJob(String rawJson, Id recordId) {
        this.rawJson  = rawJson;
        this.recordId = recordId;
    }

    public void execute(QueueableContext ctx) {
        // 1) No payload at all
        if (String.isBlank(rawJson)) {
            postToChatter(
                '⚠️ OCR failed: no data received. Please upload a clear image of your driver’s license.'
            );
            return;
        }

        // 2) Top-level array
        List<Object> wrapperList = (List<Object>) JSON.deserializeUntyped(rawJson);
        if (wrapperList.isEmpty()) {
            postToChatter(
                '⚠️ OCR failed: empty response. Please upload a valid driver’s license image.'
            );
            return;
        }

        // 3) Drill into the first action’s outputValues
        Map<String, Object> actionResp   = (Map<String, Object>) wrapperList[0];
        Map<String, Object> outputValues = (Map<String, Object>) actionResp.get('outputValues');
        if (outputValues == null
            || !outputValues.containsKey('ocrDocumentScanResultDetails')) {
            postToChatter(
                '⚠️ OCR failed: no document details found. Please upload a clear driver’s license.'
            );
            return;
        }

        // 4) Get the pages array
        Map<String, Object> detailsWrap = 
            (Map<String, Object>) outputValues.get('ocrDocumentScanResultDetails');
        List<Object> pages = 
            (List<Object>) detailsWrap.get('ocrDocumentScanResultDetails');

        if (pages == null || pages.isEmpty()) {
            postToChatter(
                '⚠️ OCR failed: could not detect any pages. Please upload a valid driver’s license image.'
            );
            return;
        }

        // 5) Build a new Identification record
        Identification__c idRec = new Identification__c();
        idRec.Application__c   = recordId;

        // 6) Your existing mapping, plus a counter
        Integer mappedCount = 0;
        for (Object pgObj : pages) {
            Map<String, Object> pageMap = (Map<String, Object>) pgObj;
            List<Object> kvps = (List<Object>) pageMap.get('keyValuePairs');
            if (kvps == null) continue;

            for (Object kvpObj : kvps) {
                Map<String, Object> pair     = (Map<String, Object>) kvpObj;
                Map<String, Object> keyMap   = (Map<String, Object>) pair.get('key');
                Map<String, Object> valueMap = (Map<String, Object>) pair.get('value');
                if (keyMap == null || valueMap == null) continue;

                String label = (String) keyMap.get('value');
                String text  = (String) valueMap.get('value');
                if (label == null || text == null) continue;

                String norm = label.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();

                if (norm.contains('4bexp')) {
                    idRec.Expiration_Date__c = text;
                    mappedCount++;
                } else if (norm.contains('8')) {
                    idRec.Address__c = text;
                    mappedCount++;
                } else if (norm.contains('15sex')) {
                    idRec.Sex__c = text;
                    mappedCount++;
                } else if (norm.contains('3dob')) {
                    idRec.Date_of_Birth__c = text;
                    mappedCount++;
                } else if (norm.contains('4ddln')) {
                    idRec.Driving_License_Number__c = text;
                    mappedCount++;
                }
                // …add other fields as needed, incrementing mappedCount on each hit…
            }
        }

         List<String> addressLines = new List<String>();
    for (Object pgObj : pages) {
        Map<String,Object> pageMap = (Map<String,Object>) pgObj;
        List<Object> kvps = (List<Object>) pageMap.get('keyValuePairs');
        if (kvps == null) continue;
        for (Object kvpObj : kvps) {
            Map<String,Object> pair     = (Map<String,Object>) kvpObj;
            Map<String,Object> keyMap   = (Map<String,Object>) pair.get('key');
            Map<String,Object> valueMap = (Map<String,Object>) pair.get('value');
            if (keyMap == null || valueMap == null) continue;

            String rawKey = ((String) keyMap.get('value')).trim().toLowerCase();
            String val    = (String) valueMap.get('value');
            if (rawKey.equals('8')
             || rawKey.startsWith('8 ')
             || rawKey.contains('apt')) {
                addressLines.add(val);
            }
        }
    }
    if (!addressLines.isEmpty()) {
        // overwrite or set the address to the joined lines
        idRec.Address__c = String.join(addressLines, ', ');
        mappedCount++;
    }

        // 7) If we never pulled back any DL fields, treat as a “bad image”
        if (mappedCount == 0) {
            postToChatter(
                '⚠️ OCR failed: no valid driver’s license data detected. Please upload a clear driver’s license image.'
            );
            return;
        }

        // 8) Finally, insert and catch any DML problems
        try {
            insert idRec;
        } catch (DmlException e) {
            String msg = e.getMessage();
            // truncate so it fits in 10k chars and doesn’t blow up
            if (msg.length() > 200) msg = msg.substring(0, 200) + '…';
            postToChatter(
                '⚠️ Could not save Identification record: ' + msg
            );
        }
    }

    /**  
     *  Posts a simple text FeedItem under the LLC_BI_Application__c record’s feed  
     */
    private void postToChatter(String body) {
        ConnectApi.ChatterFeeds.postFeedElement(
            /* communityId */ null,
            /* subjectId   */ recordId,
            /* feedType    */ ConnectApi.FeedElementType.FeedItem,
            /* text        */ body
        );
    }
}





public class IdentificationSaverJob implements Queueable {
    private String rawJson;
    private Id     parentId;

    /**
     * @param rawJson   The full JSON payload from the OCR fetch call
     * @param parentId  The Id of the LLC_BI_Application__c record to post Chatter to
     */
    public IdentificationSaverJob(String rawJson, Id parentId) {
        this.rawJson  = rawJson;
        this.parentId = parentId;
    }

    public void execute(QueueableContext ctx) {
        // 1) Nothing to parse?
        if (String.isBlank(rawJson)) {
            postChatterError('OCR payload was empty—no data to save.');
            return;
        }

        // 2) Top-level array
        List<Object> wrapper = (List<Object>) JSON.deserializeUntyped(rawJson);
        if (wrapper.isEmpty()) {
            postChatterError('Unexpected OCR response: empty array.');
            return;
        }

        // 3) Drill into outputValues → ocrDocumentScanResultDetails → ocrDocumentScanResults
        Object ov = ((Map<String,Object>) wrapper.get(0)).get('outputValues');
        if (!(ov instanceof Map<String,Object>)) {
            postChatterError('Malformed OCR JSON: missing outputValues.');
            return;
        }
        Map<String,Object> output = (Map<String,Object>) ov;

        Object detailsObj = output.get('ocrDocumentScanResultDetails');
        if (!(detailsObj instanceof Map<String,Object>)) {
            postChatterError('Malformed OCR JSON: missing scan result details.');
            return;
        }
        Map<String,Object> details = (Map<String,Object>) detailsObj;

        Object pagesObj = details.get('ocrDocumentScanResults');
        if (!(pagesObj instanceof List<Object>)) {
            postChatterError('Malformed OCR JSON: pages list missing.');
            return;
        }
        List<Object> pages = (List<Object>) pagesObj;
        if (pages.isEmpty()) {
            postChatterError('No pages found in OCR details.');
            return;
        }

        // 4) Map key/value pairs into a new Identification__c record
        Identification__c rec = new Identification__c();
        for (Object pg : pages) {
            if (!(pg instanceof Map<String,Object>)) {
                postChatterError('Malformed OCR JSON: page entry not an object.');
                continue;
            }
            Map<String,Object> pageMap = (Map<String,Object>) pg;
            List<Object> kvps = (List<Object>) pageMap.get('keyValuePairs');
            if (kvps == null) continue;

            for (Object kvpObj : kvps) {
                if (!(kvpObj instanceof Map<String,Object>)) {
                    postChatterError('Malformed OCR JSON: keyValuePairs entry not a map.');
                    continue;
                }
                Map<String,Object> pair = (Map<String,Object>) kvpObj;

                Object keyObj = pair.get('key');
                Object valObj = pair.get('value');
                if (!(keyObj instanceof Map<String,Object>) ||
                    !(valObj instanceof Map<String,Object>)) {
                    postChatterError('Malformed OCR JSON: key or value not an object.');
                    continue;
                }

                Map<String,Object> keyMap   = (Map<String,Object>) keyObj;
                Map<String,Object> valueMap = (Map<String,Object>) valObj;
                String label = (String) keyMap.get('value');
                String text  = (String) valueMap.get('value');
                if (label == null || text == null) continue;

                // ► Your mapping logic here
                String norm = label.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();
                if (norm.contains('4bexp'))      rec.Expiration_Date__c         = text;
                else if (norm.contains('8'))     rec.Address__c                 = text;
                else if (norm.contains('15sex')) rec.Sex__c                     = text;
                else if (norm.contains('3dob'))  rec.Date_of_Birth__c           = text;
                else if (norm.contains('4ddln')) rec.Driving_License_Number__c = text;
            }
        }

        // 5) Save the record (or report a DML error)
        try {
            insert rec;
        } catch (DmlException ex) {
            postChatterError('Failed to save Identification record: ' + ex.getMessage());
        }
    }

    /**
     * Posts a plain-text Chatter feed element on the parent record.
     * Uses the v31+ signature:
     *   postFeedElement(String communityId,
     *                   String subjectId,
     *                   FeedElementType feedElementType,
     *                   String text)
     */
   private void postChatterError(String message) {
    // try to grab Name via dynamic SOQL
    String appName;
    try {
        // Note: this will compile even if there's no static SObject type
        SObject rec = Database.query(
            'SELECT Name FROM LLC_BI_Application__c WHERE Id = \'' 
            + parentId + '\''
        );
        appName = (String) rec.get('Name');
    } catch (Exception e) {
        appName = parentId.toString();
    }

    String bodyText = '⚠️ Error processing document on "' 
                    + appName 
                    + '": ' 
                    + message;

    ConnectApi.ChatterFeeds.postFeedElement(
        /* communityId    */ null,
        /* subjectId      */ parentId.toString(),
        /* feedElementType*/ ConnectApi.FeedElementType.FeedItem,
        /* text           */ bodyText
    );
}

}

private void postChatterError(String message) {
    // try to grab Name via dynamic SOQL
    String appName;
    try {
        // Note: this will compile even if there's no static SObject type
        SObject rec = Database.query(
            'SELECT Name FROM LLC_BI_Application__c WHERE Id = \'' 
            + parentId + '\''
        );
        appName = (String) rec.get('Name');
    } catch (Exception e) {
        appName = parentId.toString();
    }

    String bodyText = '⚠️ Error processing document on "' 
                    + appName 
                    + '": ' 
                    + message;

    ConnectApi.ChatterFeeds.postFeedElement(
        /* communityId    */ null,
        /* subjectId      */ parentId.toString(),
        /* feedElementType*/ ConnectApi.FeedElementType.FeedItem,
        /* text           */ bodyText
    );
}



