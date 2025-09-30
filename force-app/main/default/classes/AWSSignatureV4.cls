// AWSSignatureV4.cls - AWS Signature Version 4 Implementation
public class AWSSignatureV4 {
    
    private static final String ALGORITHM = 'AWS4-HMAC-SHA256';
    private static final String TERMINATION_STRING = 'aws4_request';
    
    public class SignatureResult {
        public String authorization;
        public String dTime;
        public String dA;
    }
    
    public static SignatureResult generateSignature(
        String httpMethod,
        String endpoint,
        String requestUri,
        Map<String, String> headers,
        String payload,
        String accessKey,
        String secretKey,
        String region,
        String service
    ) {
        // Step 1: Create timestamp
        String dTime = Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dA = dTime.substring(0, 8);
        
        // Step 2: Create a new headers map to avoid modifying the original
        Map<String, String> allHeaders = new Map<String, String>();
        
        // Add all existing headers with lowercase keys
        for (String key : headers.keySet()) {
            allHeaders.put(key.toLowerCase(), headers.get(key));
        }
        
        // Add required AWS headers (must be lowercase for canonical request)
        allHeaders.put('x-amz-date', dTime);
        
        // Ensure host header is present
        if (!allHeaders.containsKey('host')) {
            allHeaders.put('host', getHostFromEndpoint(endpoint));
        }
        
        // Step 3: Create canonical request
        String canonicalRequest = createCanonicalRequest(
            httpMethod, requestUri, allHeaders, payload
        );
        
        System.debug('Canonical Request:\n' + canonicalRequest);
        
        // Step 4: Create string to sign
        String credentialScope = dA + '/' + region + '/' + service + '/' + TERMINATION_STRING;
        String stringToSign = createStringToSign(dTime, credentialScope, canonicalRequest);
        
        System.debug(LoggingLevel.DEBUG,'String to Sign:\n' + stringToSign);
        
        // Step 5: Calculate signature
        String signature = calculateSignature(secretKey, dA, region, service, stringToSign);
        
        System.debug(LoggingLevel.DEBUG,'Signature: ' + signature);
        
        // Step 6: Create authorization header
        String signedHeaders = getSignedHeaders(allHeaders);
        String authorization = ALGORITHM + ' ' +
            'Credential=' + accessKey + '/' + credentialScope + ', ' +
            'SignedHeaders=' + signedHeaders + ', ' +
            'Signature=' + signature;

        System.debug(LoggingLevel.DEBUG,'Authorization: ' + authorization);
        System.debug(LoggingLevel.DEBUG,'X-Amz-Date: ' + dTime);
        
        SignatureResult result = new SignatureResult();
        result.authorization = authorization;
        result.dTime = dTime;
        result.dA = dA;
        
        return result;
    }
    
    private static String createCanonicalRequest(
        String httpMethod,
        String requestUri,
        Map<String, String> headers,
        String payload
    ) {
        // Canonical URI
        String canonicalUri = requestUri;
        if (String.isBlank(canonicalUri)) {
            canonicalUri = '/';
        }
        
        // Canonical Query String (empty for POST requests)
        String canonicalQueryString = '';
        
        // Canonical Headers
        String canonicalHeaders = createCanonicalHeaders(headers);
        
        // Signed Headers
        String signedHeaders = getSignedHeaders(headers);
        
        // Payload Hash
        String payloadHash = hashSHA256(payload);
        
        String canonical = httpMethod + '\n' +
                          canonicalUri + '\n' +
                          canonicalQueryString + '\n' +
                          canonicalHeaders + '\n' +
                          signedHeaders + '\n' +
                          payloadHash;
        
        return canonical;
    }
    
    private static String createCanonicalHeaders(Map<String, String> headers) {
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        
        String canonicalHeaders = '';
        for (String key : sortedKeys) {
            String headerKey = key.toLowerCase().trim();
            String headerValue = headers.get(key).trim();
            // Replace multiple spaces with single space
            headerValue = headerValue.replaceAll('\\s+', ' ');
            canonicalHeaders += headerKey + ':' + headerValue + '\n';
        }
        
        return canonicalHeaders;
    }
    
    private static String getSignedHeaders(Map<String, String> headers) {
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        
        List<String> lowerCaseKeys = new List<String>();
        for (String key : sortedKeys) {
            lowerCaseKeys.add(key.toLowerCase().trim());
        }
        
        return String.join(lowerCaseKeys, ';');
    }
    
    private static String createStringToSign(
        String dTime,
        String credentialScope,
        String canonicalRequest
    ) {
        return ALGORITHM + '\n' +
               dTime + '\n' +
               credentialScope + '\n' +
               hashSHA256(canonicalRequest);
    }
    
    private static String calculateSignature(
        String secretKey,
        String dA,
        String region,
        String service,
        String stringToSign
    ) {
        Blob kSecret = Blob.valueOf('AWS4' + secretKey);
        Blob kDate = signHMAC(kSecret, dA);
        Blob kRegion = signHMAC(kDate, region);
        Blob kService = signHMAC(kRegion, service);
        Blob kSigning = signHMAC(kService, TERMINATION_STRING);
        
        Blob signature = signHMAC(kSigning, stringToSign);
        return EncodingUtil.convertToHex(signature);
    }
    
    private static Blob signHMAC(Blob key, String message) {
        return Crypto.generateMac('HmacSHA256', Blob.valueOf(message), key);
    }
    
    private static String hashSHA256(String input) {
        Blob inputBlob = Blob.valueOf(input);
        Blob hash = Crypto.generateDigest('SHA256', inputBlob);
        return EncodingUtil.convertToHex(hash);
    }
    
    private static String getHostFromEndpoint(String endpoint) {
        String host = endpoint;
        if (host.startsWith('https://')) {
            host = host.substring(8);
        } else if (host.startsWith('http://')) {
            host = host.substring(7);
        }
        
        if (host.contains('/')) {
            host = host.substring(0, host.indexOf('/'));
        }
        
        System.debug('Host: ' + host);
        return host;
    }
}