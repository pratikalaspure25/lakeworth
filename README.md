if (ocrResult == null
            || ocrResult.startsWith('Error')
            || ocrResult.contains('No OCR results')) {
          FeedItem f = new FeedItem(
            ParentId = parentId,
            Body     = '⚠️ Document processing failed: ' + ocrResult +
                       '. Please upload a clear Driver’s License image.'
          );
          insert f;
          return;
        }
