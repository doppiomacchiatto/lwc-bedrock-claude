// AWSSignatureDebugger.cls - Utility for debugging AWS signature issues
public class AWSSignatureDebugger {
    
    public static void debugSignatureGeneration(
        String httpMethod,
        String endpoint,
        String requestUri,
        Map<String, String> headers,
        String payload,
        String accessKey,
        String region,
        String service
    ) {
        System.debug('=== AWS Signature V4 Debug Information ===');
        System.debug('HTTP Method: ' + httpMethod);
        System.debug('Endpoint: ' + endpoint);
        System.debug('Request URI: ' + requestUri);
        System.debug('Region: ' + region);
        System.debug('Service: ' + service);
        System.debug('Access Key: ' + accessKey);
        
        // Display headers
        System.debug('\n--- Headers ---');
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        for (String key : sortedKeys) {
            System.debug(key + ': ' + headers.get(key));
        }
        
        // Display payload
        System.debug('\n--- Payload ---');
        System.debug('Payload Length: ' + payload.length());
        System.debug('Payload Hash: ' + hashSHA256(payload));
        
        // Display canonical request components
        System.debug('\n--- Canonical Request Components ---');
        String dTime = Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String da = dTime.substring(0, 8);
        
        Map<String, String> allHeaders = new Map<String, String>(headers);
        allHeaders.put('x-amz-date', dTime);
        
        String canonicalHeaders = createCanonicalHeaders(allHeaders);
        String signedHeaders = getSignedHeaders(allHeaders);
        
        System.debug('Canonical Headers:\n' + canonicalHeaders);
        System.debug('Signed Headers: ' + signedHeaders);
        
        // Display credential scope
        String credentialScope = da + '/' + region + '/' + service + '/aws4_request';
        System.debug('\n--- Credential Scope ---');
        System.debug(credentialScope);
        
        System.debug('=== End Debug Information ===\n');
    }
    
    private static String createCanonicalHeaders(Map<String, String> headers) {
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        
        String canonicalHeaders = '';
        for (String key : sortedKeys) {
            canonicalHeaders += key.toLowerCase() + ':' + 
                               headers.get(key).trim() + '\n';
        }
        
        return canonicalHeaders;
    }
    
    private static String getSignedHeaders(Map<String, String> headers) {
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        
        List<String> lowerCaseKeys = new List<String>();
        for (String key : sortedKeys) {
            lowerCaseKeys.add(key.toLowerCase());
        }
        
        return String.join(lowerCaseKeys, ';');
    }
    
    private static String hashSHA256(String input) {
        Blob inputBlob = Blob.valueOf(input);
        Blob hash = Crypto.generateDigest('SHA256', inputBlob);
        return EncodingUtil.convertToHex(hash);
    }
    
    // Test method to validate signature generation
    public static void testSignatureWithKnownValues() {
        System.debug('=== Testing AWS Signature with Known Values ===');
        
        String endpoint = 'https://bedrock-runtime.us-east-1.amazonaws.com';
        String requestUri = '/model/us.anthropic.claude-3-7-sonnet-20250219-v1:0/invoke';
        String payload = '{"messages":[{"role":"user","content":"Hello"}],"anthropic_version":"bedrock-2023-05-31","max_tokens":1000}';
        
        Map<String, String> headers = new Map<String, String>{
            'content-type' => 'application/json',
            'host' => 'bedrock-runtime.us-east-1.amazonaws.com'
        };
        
        debugSignatureGeneration(
            'POST',
            endpoint,
            requestUri,
            headers,
            payload,
            'AKIAIOSFODNN7EXAMPLE',
            'us-east-1',
            'bedrock'
        );
    }
}