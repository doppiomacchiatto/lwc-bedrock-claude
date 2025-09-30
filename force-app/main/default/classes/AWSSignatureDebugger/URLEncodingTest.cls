// URLEncodingTest.cls - Test to verify URL encoding
@isTest
public class URLEncodingTest {
    
    @isTest
    static void testModelIdEncoding() {
        // Test various model IDs to ensure proper encoding
        Map<String, String> testCases = new Map<String, String>{
            'us.anthropic.claude-3-7-sonnet-20250219-v1:0' => 
                '/model/us.anthropic.claude-3-7-sonnet-20250219-v1%3A0/invoke',
            'anthropic.claude-3-sonnet-20240229-v1:0' => 
                '/model/anthropic.claude-3-sonnet-20240229-v1%3A0/invoke',
            'test-model:v2:0' => 
                '/model/test-model%3Av2%3A0/invoke'
        };
        
        for (String modelId : testCases.keySet()) {
            String expectedUri = testCases.get(modelId);
            String actualUri = encodeModelIdInPath(modelId);
            
            System.debug('Model ID: ' + modelId);
            System.debug('Expected: ' + expectedUri);
            System.debug('Actual: ' + actualUri);
            
            System.assertEquals(expectedUri, actualUri, 
                'URI encoding failed for model: ' + modelId);
        }
    }
    
    private static String encodeModelIdInPath(String modelId) {
        // Simulate the path construction
        String path = '/model/' + modelId + '/invoke';
        
        // Split and encode
        List<String> segments = path.split('/', 0);
        List<String> encodedSegments = new List<String>();
        
        for (String segment : segments) {
            if (String.isNotBlank(segment)) {
                if (segment == 'model' || segment == 'invoke') {
                    // Don't encode these path segments
                    encodedSegments.add(segment);
                } else {
                    // Encode the model ID
                    String encoded = EncodingUtil.urlEncode(segment, 'UTF-8');
                    encoded = encoded.replace('+', '%20');
                    encodedSegments.add(encoded);
                }
            }
        }
        
        return '/' + String.join(encodedSegments, '/');
    }
    
    @isTest
    static void testFullEndpointExtraction() {
        // Test extracting and encoding URI from full endpoint
        String fullEndpoint = 'https://bedrock-runtime.us-east-1.amazonaws.com/model/us.anthropic.claude-3-7-sonnet-20250219-v1:0/invoke';
        
        String expectedUri = '/model/us.anthropic.claude-3-7-sonnet-20250219-v1%3A0/invoke';
        String actualUri = extractAndEncodeUri(fullEndpoint);
        
        System.debug('Full Endpoint: ' + fullEndpoint);
        System.debug('Expected URI: ' + expectedUri);
        System.debug('Actual URI: ' + actualUri);
        
        System.assertEquals(expectedUri, actualUri, 
            'Failed to extract and encode URI from endpoint');
    }
    
    private static String extractAndEncodeUri(String endpoint) {
        String uri = '/';
        
        if (endpoint.contains('://')) {
            String afterProtocol = endpoint.substringAfter('://');
            if (afterProtocol.contains('/')) {
                uri = '/' + afterProtocol.substringAfter('/');
            }
        }
        
        // Encode the URI
        List<String> segments = uri.split('/', 0);
        List<String> encodedSegments = new List<String>();
        
        for (String segment : segments) {
            if (String.isNotBlank(segment)) {
                String encoded = EncodingUtil.urlEncode(segment, 'UTF-8');
                encoded = encoded.replace('+', '%20');
                encodedSegments.add(encoded);
            }
        }
        
        return '/' + String.join(encodedSegments, '/');
    }
    
    @isTest
    static void testColonEncoding() {
        // Specifically test that colons are encoded as %3A
        String input = 'v1:0';
        String encoded = EncodingUtil.urlEncode(input, 'UTF-8');
        
        System.debug('Input: ' + input);
        System.debug('Encoded: ' + encoded);
        
        System.assert(encoded.contains('%3A'), 
            'Colon should be encoded as %3A, got: ' + encoded);
    }
}