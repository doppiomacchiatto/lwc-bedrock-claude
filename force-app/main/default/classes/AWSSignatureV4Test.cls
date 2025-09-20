/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
// AWSSignatureV4Test.cls - Test class for AWS Signature V4 implementation
@isTest
public class AWSSignatureV4Test {
    
    @isTest
    static void testSignatureGeneration() {
        // Test data based on AWS documentation examples
        String httpMethod = 'POST';
        String endpoint = 'https://bedrock-runtime.us-east-1.amazonaws.com';
        String requestUri = '/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke';
        String payload = '{"messages":[{"role":"user","content":"Hello"}]}';
        String accessKey = 'AKIAIOSFODNN7EXAMPLE';
        String secretKey = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
        String region = 'us-east-1';
        String service = 'bedrock';
        
        Map<String, String> headers = new Map<String, String>{
            'content-type' => 'application/json',
            'accept' => 'application/json'
        };
        
        Test.startTest();
        
        AWSSignatureV4.SignatureResult result = AWSSignatureV4.generateSignature(
            httpMethod,
            endpoint,
            requestUri,
            headers,
            payload,
            accessKey,
            secretKey,
            region,
            service
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Signature result should not be null');
        System.assertNotEquals(null, result.authorization, 'Authorization header should not be null');
        System.assert(result.authorization.startsWith('AWS4-HMAC-SHA256'), 'Authorization should start with AWS4-HMAC-SHA256');
        System.assert(result.authorization.contains('Credential='), 'Authorization should contain Credential');
        System.assert(result.authorization.contains('SignedHeaders='), 'Authorization should contain SignedHeaders');
        System.assert(result.authorization.contains('Signature='), 'Authorization should contain Signature');
        
        // Verify date format
        System.assertEquals(8, result.dia.length(), 'Date should be 8 characters (YYYYMMDD)');
        System.assertEquals(16, result.dTime.length(), 'DateTime should be 16 characters (YYYYMMDDTHHMMSSZ)');
        System.assert(result.dTime.endsWith('Z'), 'DateTime should end with Z');
    }
    
    @isTest
    static void testCanonicalRequestCreation() {
        // Test the canonical request creation with known values
        String httpMethod = 'POST';
        String requestUri = '/test/path';
        Map<String, String> headers = new Map<String, String>{
            'host' => 'example.amazonaws.com',
            'x-amz-date' => '20230101T120000Z',
            'content-type' => 'application/json'
        };
        String payload = '{"test": "value"}';
        
        // This tests the private method indirectly through the public method
        AWSSignatureV4.SignatureResult result = AWSSignatureV4.generateSignature(
            httpMethod,
            'https://example.amazonaws.com',
            requestUri,
            new Map<String, String>(headers), // Clone to avoid modification
            payload,
            'AKIATEST',
            'testSecretKey',
            'us-east-1',
            'bedrock'
        );
        
        System.assertNotEquals(null, result, 'Should generate a signature result');
    }
    
    @isTest
    static void testHostExtraction() {
        // Test various endpoint formats
        Map<String, String> testCases = new Map<String, String>{
            'https://bedrock-runtime.us-east-1.amazonaws.com' => 'bedrock-runtime.us-east-1.amazonaws.com',
            'http://example.com/path' => 'example.com',
            'https://test.amazonaws.com/model/invoke' => 'test.amazonaws.com'
        };
        
        // Since getHostFromEndpoint is private, we test it indirectly
        for (String endpoint : testCases.keySet()) {
            AWSSignatureV4.SignatureResult result = AWSSignatureV4.generateSignature(
                'POST',
                endpoint,
                '/',
                new Map<String, String>{'content-type' => 'application/json'},
                '{}',
                'AKIATEST',
                'testSecret',
                'us-east-1',
                'bedrock'
            );
            
            System.assertNotEquals(null, result, 'Should handle endpoint: ' + endpoint);
        }
    }
    
    @isTest
    static void testEmptyPayload() {
        // Test with empty payload
        AWSSignatureV4.SignatureResult result = AWSSignatureV4.generateSignature(
            'GET',
            'https://bedrock-runtime.us-east-1.amazonaws.com',
            '/',
            new Map<String, String>{'content-type' => 'application/json'},
            '',
            'AKIATEST',
            'testSecret',
            'us-east-1',
            'bedrock'
        );
        
        System.assertNotEquals(null, result, 'Should handle empty payload');
        System.assert(result.authorization.contains('Signature='), 'Should generate valid signature for empty payload');
    }
    
    @isTest
    static void testDifferentRegions() {
        List<String> regions = new List<String>{'us-east-1', 'us-west-2', 'eu-west-1'};
        
        for (String region : regions) {
            AWSSignatureV4.SignatureResult result = AWSSignatureV4.generateSignature(
                'POST',
                'https://bedrock-runtime.' + region + '.amazonaws.com',
                '/model/test/invoke',
                new Map<String, String>{'content-type' => 'application/json'},
                '{"test": true}',
                'AKIATEST',
                'testSecret',
                region,
                'bedrock'
            );
            
            System.assertNotEquals(null, result, 'Should handle region: ' + region);
            System.assert(result.authorization.contains(region), 'Authorization should contain region: ' + region);
        }
    }
}