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
            
            // Parse and return Claude's response
            return parseClaudeResponse(response);
            
        } catch (Exception e) {
            System.debug('Error in sendMessage: ' + e.getMessage());
            throw new AuraHandledException('Failed to send message to Claude: ' + e.getMessage());
        }
    }
    
private static Map<String, Object> buildClaudeRequestPayload(String message, List<ConversationMessage> conversationHistory) {
        List<Map<String, Object>> messages = new List<Map<String, Object>>();
        //For this application we will use the same role for all messages.
        //This is not a best practice, but it is a simple way to get started.
        String role = 'user';
        /**
         * TODO - Refactory null check.
         */
        // Add conversation history
        if (conversationHistory != null) {
            System.debug(LoggingLevel.DEBUG,'conversationHistory is not Null: '+conversationHistory);
            for (ConversationMessage historyMsg : conversationHistory) {

                if(historyMsg.role != null || historyMsg.content != null){
                    System.debug(LoggingLevel.DEBUG, 'historyMsg: '+historyMsg);
                    System.debug(LoggingLevel.DEBUG, 'historyMsg.role: '+historyMsg.role);
                }else{
                    System.debug(LoggingLevel.DEBUG, 'historyMsg.role was Null');
                    historyMsg.role = role;
                    historyMsg.content = 'Initializing conversation...';
                }

                messages.add(new Map<String, Object>{
                    'role' => historyMsg.role.toLowerCase(),
                    'content' => new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'type' => 'text',
                            'text' => historyMsg.content
                        }
                    }
                });
            }
        }
        
        // Add current user message
        messages.add(new Map<String, Object>{
            'role' => role,
            'content' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => message
                }
            }
        });
        
        // Build the complete request payload for Claude 3.x Messages API format
        Map<String, Object> payload = new Map<String, Object>{
            'anthropic_version' => 'bedrock-2023-05-31',
            'max_tokens' => 4096,
            'messages' => messages
        };
        
        System.debug('Request Payload: ' + JSON.serializePretty(payload));
        
        return payload;
    }
    
    private static String callBedrockAPI(Map<String, Object> requestPayload) {
        // Get AWS credentials from custom metadata or named credentials
        AWSCredentials credentials = getAWSCredentials();
        
        String requestBody = JSON.serialize(requestPayload);
        
        // Build endpoint URL - model ID will be URL encoded in the request URI
        String endpoint = BEDROCK_ENDPOINT + '/model/' + BEDROCK_MODEL_ID + '/invoke';
        
        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setTimeout(120000); // 2 minutes timeout
        
        System.debug('Full Endpoint (before encoding): ' + endpoint);
        
        // Add AWS authentication headers (this will handle URL encoding)
        addAWSAuthHeaders(req, requestBody, credentials);
        
        // Set body after headers are calculated
        req.setBody(requestBody);
        
        // Make the request
        Http http = new Http();
        HttpResponse res = http.send(req);
        try{   
            if (res.getStatusCode() != 200) {
                String errorBody = res.getBody();
                System.debug('AWS Bedrock Error - Status: ' + res.getStatusCode());
                System.debug('AWS Bedrock Error - Body: ' + errorBody);
                throw new CalloutException('AWS Bedrock API call failed: ' + res.getStatusCode() + ' - ' + errorBody);
            }
            else if (res.getStatusCode() == 403 ||  
                    res.getStatusCode() == 401 ||  
                    res.getStatusCode() == 400 ||  
                    res.getStatusCode() == 404 ||  
                    res.getStatusCode() == 405 ) {
                String errorBody = res.getBody();
                System.debug('AWS Bedrock Error - Status: ' + res.getStatusCode());
                System.debug('AWS Bedrock Error - Body: ' + errorBody);
                throw new CalloutException('AWS Bedrock API call failed: ' + res.getStatusCode() + ' - ' + errorBody); 
            }
        }catch (CalloutException e){
            System.debug(LoggingLevel.ERROR,'Error in callBedrockAPI: ' + e.getMessage());
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
    
        // Get the endpoint components
    private static void addAWSAuthHeaders(HttpRequest req, String requestBody, AWSCredentials credentials) {
        // Get the endpoint components
        String endpoint = req.getEndpoint();
        String requestUri = getRequestUriFromEndpoint(endpoint);
        String host = getHostFromEndpoint(endpoint);
        
        System.debug('=== AWS Request Details ===');
        System.debug('Endpoint: ' + endpoint);
        System.debug('Request URI: ' + requestUri);
        System.debug('Host: ' + host);
        System.debug('Method: ' + req.getMethod());
        System.debug('Body Length: ' + requestBody.length());
        
        // Prepare headers for signing (use lowercase keys as required by AWS)
        // AWS Bedrock requires specific accept header format
        Map<String, String> headersForSigning = new Map<String, String>{
            'accept' => '*/*',
            'content-type' => 'application/json',
            'host' => host
        };
        
        // Generate AWS Signature V4
        // Generate AWS Signature V4
        AWSSignatureV4.SignatureResult signature = AWSSignatureV4.generateSignature(
            req.getMethod(),
            endpoint,
            requestUri,
            headersForSigning,
            requestBody,
            credentials.accessKeyId,
            credentials.secretAccessKey,
            credentials.region,
            'bedrock'
        );
        
        // IMPORTANT: Set headers on HttpRequest object
        // Note: HttpRequest uses proper case, but signature calculation uses lowercase
        req.setHeader('Accept', '*/*');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Host', host);
        req.setHeader('X-Amz-Date', signature.dTime);
        req.setHeader('Authorization', signature.authorization);
        
        System.debug('=== Headers Set on Request ===');
        System.debug('Accept: */*');
        System.debug('Content-Type: application/json');
        System.debug('Host: ' + host);
        System.debug('X-Amz-Date: ' + signature.dTime);
        System.debug('Authorization: ' + signature.authorization);
    }
    
    private static String getRequestUriFromEndpoint(String endpoint) {
        String uri = '/';
        
        // Extract URI path from full endpoint
        if (endpoint.contains('://')) {
            String afterProtocol = endpoint.substringAfter('://');
            if (afterProtocol.contains('/')) {
                uri = '/' + afterProtocol.substringAfter('/');
            }
        }
        
        // URL encode the URI path (specifically for model IDs with colons)
        uri = encodeURIPath(uri);
        
        System.debug('Request URI (encoded): ' + uri);
        return uri;
    }
    
    private static String encodeURIPath(String path) {
        // Split path into segments to encode each part
        List<String> segments = path.split('/', 0);
        List<String> encodedSegments = new List<String>();
        
        for (String segment : segments) {
            if (String.isNotBlank(segment)) {
                // Encode special characters, particularly colon (:) to %3A
                String encoded = EncodingUtil.urlEncode(segment, 'UTF-8');
                // EncodingUtil.urlEncode uses + for spaces, but we need %20
                // and it encodes / which we don't want encoded in the path
                encoded = encoded.replace('+', '%20');
                encodedSegments.add(encoded);
            }
        }
        
        // Reconstruct path with / separators
        String encodedPath = '/' + String.join(encodedSegments, '/');
        
        return encodedPath;
    }
    
    private static String getHostFromEndpoint(String endpoint) {
        String host = endpoint;
        
        // Remove protocol
        if (host.startsWith('https://')) {
            host = host.substring(8);
        } else if (host.startsWith('http://')) {
            host = host.substring(7);
        }
        
        // Remove path
        if (host.contains('/')) {
            host = host.substring(0, host.indexOf('/'));
        }
        
        return host;
    }
    
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