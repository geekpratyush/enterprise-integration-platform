<?xml version="1.0" encoding="UTF-8"?>
<!--
    XSLT: TARGET2_pacs008_to_MT103.xslt
    Clearing: TARGET2 (RTGS Euro)
    Inherits from: Base_pacs008_to_MT103.xslt
    
    Description:
    Specialization for TARGET2 reverse translation. 
    Inherits the core truncation and mapping logic from the Base XSLT.
-->
<xsl:stylesheet version="3.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs">

    <xsl:import href="Base_pacs008_to_MT103.xslt"/>

    <!-- 
        OVERRIDE: Add T2-specific identifiers in Field 72 
        to ensure the legacy system recognizes this as an RTGS payment.
    -->
    <xsl:template match="*[local-name()='CdtTrfTxInf']">
        <!-- We call the base template first to generate the standard MT blocks -->
        <xsl:variable name="baseMT">
            <xsl:apply-imports/>
        </xsl:variable>

        <!-- 
            We inject T2 Specifics after the standard Remittance (:70:) 
            but before the end of the block 4 (-}) 
        -->
        <xsl:variable name="tsh" select="'/TGT/'"/> <!-- T2 Service Indicator -->
        
        <xsl:value-of select="substring($baseMT, 1, string-length($baseMT) - 2)"/>
        
        <!-- :72: SENDER TO RECEIVER INFORMATION (T2 Specifics) -->
        <xsl:text>:72:</xsl:text>
        <xsl:value-of select="$tsh"/>
        <xsl:text>&#10;</xsl:text>
        
        <xsl:text>-}</xsl:text>
    </xsl:template>

</xsl:stylesheet>
