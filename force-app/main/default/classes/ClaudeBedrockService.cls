// ClaudeBedrockService.cls
public with sharing class ClaudeBedrockService {
    
    // AWS Bedrock endpoint configuration
    private static final String BEDROCK_REGION = 'us-east-1'; // Configure as needed
    private static final String BEDROCK_MODEL_ID = 'us.anthropic.claude-3-7-sonnet-20250219-v1:0';
    private static final String BEDROCK_ENDPOINT = 'https://bedrock-runtime.' + BEDROCK_REGION + '.amazonaws.com';
    
    @AuraEnabled
    public static String sendMessage(String message, List<ConversationMessage> conversationHistory) {
        try {
            // Validate input
            if (String.isBlank(message)) {
                throw new AuraHandledException('Message cannot be empty');
            }
            
            // Build the request payload for Claude
            Map<String, Object> requestPayload = buildClaudeRequestPayload(message, conversationHistory);
            
            // Make the HTTP request to AWS Bedrock
            String response = callBedrockAPI(requestPayload);
            System.debug(LoggingLevel.DEBUG, 'response: '+response);
            
            // Parse and return Claude's response
            return parseClaudeResponse(response);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,'Error in sendMessage: ' + e.getMessage());
            throw new AuraHandledException('Failed to send message to Claude: ' + e.getMessage());
        }
    }
    
    private static Map<String, Object> buildClaudeRequestPayload(String message, List<ConversationMessage> conversationHistory) {
        List<Map<String, Object>> messages = new List<Map<String, Object>>();
        
        // Add conversation history
        if (conversationHistory != null) {
            for (ConversationMessage historyMsg : conversationHistory) {
                messages.add(new Map<String, Object>{
                    'role' => historyMsg.role,
                    'content' => historyMsg.content
                });
            }
        }
        
        // Add current user message
        messages.add(new Map<String, Object>{
            'role' => 'user',
            'content' => message
        });
        
        // Build the complete request payload
        Map<String, Object> payload = new Map<String, Object>{
            'anthropic_version' => 'bedrock-2023-05-31',
            'max_tokens' => 4000,
            'temperature' => 0.7,
            'messages' => messages,
            'system' => 'You are Claude, a helpful AI assistant created by Anthropic. You are integrated into a Salesforce Lightning Web Component to provide real-time chat capabilities. Be helpful, accurate, and conversational.'
        };
        
        return payload;
    }
    
    private static String callBedrockAPI(Map<String, Object> requestPayload) {
        // Get AWS credentials from custom metadata or named credentials
        AWSCredentials credentials = getAWSCredentials();
        
        String requestBody = JSON.serialize(requestPayload);
        String endpoint = BEDROCK_ENDPOINT + '/model/' + BEDROCK_MODEL_ID + '/invoke';
        
        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000); // 2 minutes timeout
        
        // Add AWS authentication headers
        addAWSAuthHeaders(req, requestBody, credentials);
        //Refactored to use the AWSSignatureV4.cls (service)
        
        req.setBody(requestBody);
        System.debug(LoggingLevel.DEBUG, 'http eeq: '+req);
        System.debug(LoggingLevel.DEBUG,'payload: '+requestBody);
        System.debug(LoggingLevel.DEBUG, 'endpoint: '+endpoint);
        System.debug(LoggingLevel.DEBUG, 'credentials: '+credentials);
        
        // Make the request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException('AWS Bedrock API call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        
        return res.getBody();
    }
    
    private static String parseClaudeResponse(String responseBody) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> content = (List<Object>) responseMap.get('content');
            
            if (content != null && !content.isEmpty()) {
                Map<String, Object> textContent = (Map<String, Object>) content[0];
                return (String) textContent.get('text');
            }
            
            throw new AuraHandledException('Invalid response format from Claude');
            
        } catch (Exception e) {
            System.debug('Error parsing Claude response: ' + e.getMessage());
            throw new AuraHandledException('Failed to parse Claude response');
        }
    }
    
    private static AWSCredentials getAWSCredentials() {
        // Option 1: Use Named Credentials (Recommended)
        // This method assumes you have a Named Credential configured for AWS
        // The actual implementation would depend on your AWS authentication setup
        
        try {
            // Try to get credentials from custom metadata
            AWS_Bedrock_Config__mdt config = [
                SELECT Access_Key_Id__c, Secret_Access_Key__c, Region__c 
                FROM AWS_Bedrock_Config__mdt 
                LIMIT 1
            ];
            
            return new AWSCredentials(
                config.Access_Key_Id__c,
                config.Secret_Access_Key__c,
                config.Region__c != null ? config.Region__c : BEDROCK_REGION
            );
        } catch (QueryException e) {
            // Fallback to environment variables or throw error
            throw new AuraHandledException('AWS credentials not configured. Please set up AWS_Bedrock_Config custom metadata.');
        }
    }
    
    private static void addAWSAuthHeaders(HttpRequest req, String requestBody, AWSCredentials credentials) {
        // Implement AWS Signature Version 4 authentication
        // This is a simplified version - you might want to use a more robust implementation
        
        String dTime = Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dia = dTime.substring(0, 8);
        String credentialScope = dia + '/' + credentials.region + '/bedrock/aws4_request';
        String signedHeaders = 'content-type;host;x-amz-date';
        String httpMethod = 'POST';
        String endpoint = 'https://bedrock-runtime.us-east-1.amazonaws.com';
        String requestUri = '/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke';
        String service = 'bedrock';
        // For production, implement full AWS Signature V4
        // This is a simplified version for demonstration
        Map<String,String> headers = new Map<String,String>();
        // Add required headers
        headers.put('content-type', 'application/json');
        headers.put('accept', 'application/json');
        AWSSignatureV4.SignatureResult result = AWSSignatureV4.generateSignature(
            httpMethod,
            endpoint,
            requestUri,
            headers,
            requestBody, 
            getAWSCredentials().accessKeyId,
            getAWSCredentials().secretAccessKey,
            getAWSCredentials().region,
            service);
        req.setHeader('Authorization', result.authorization);
    }
    
    // Wrapper classes
    public class ConversationMessage {
        @AuraEnabled public String role;
        @AuraEnabled public String content;
    }
    
    private class AWSCredentials {
        public String accessKeyId;
        public String secretAccessKey;
        public String region;
        
        public AWSCredentials(String accessKeyId, String secretAccessKey, String region) {
            this.accessKeyId = accessKeyId;
            this.secretAccessKey = secretAccessKey;
            this.region = region;
        }
    }
}