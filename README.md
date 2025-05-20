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
        // (Optional) grab the record Name for friendlier text
        String appName;
        try {
            appName = [SELECT Name FROM LLC_BI_Application__c WHERE Id = :parentId].Name;
        } catch (Exception e) {
            appName = parentId;
        }

        // Build your plain-text body
        String bodyText = '⚠️ Error processing document on "' 
                        + appName 
                        + '": ' 
                        + message;

        // Fire the feed
        ConnectApi.ChatterFeeds.postFeedElement(
            /* communityId    */ null,
            /* subjectId      */ parentId.toString(),
            /* feedElementType*/ ConnectApi.FeedElementType.FeedItem,
            /* text           */ bodyText
        );
    }
}
