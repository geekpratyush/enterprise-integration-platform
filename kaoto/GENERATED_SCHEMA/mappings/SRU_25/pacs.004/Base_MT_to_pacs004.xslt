<?xml version="1.0" encoding="UTF-8"?>
<!--
    XSLT: Base_MT103RETR_to_pacs004.xslt (SRU_25)
    Author: Antigravity AI
    
    Description:
    Translates a SWIFT MT103 (treated as a Return/Reversal) to pacs.004.001.13.
-->
<xsl:stylesheet version="3.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mt="http://www.prowidesoftware.com/pw-swift-core/mt"
    exclude-result-prefixes="xs mt">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <xsl:param name="Target_Namespace" select="'urn:iso:std:iso:20022:tech:xsd:pacs.004.001.13'"/>
    <xsl:param name="BAH_Namespace" select="'urn:iso:std:iso:20022:tech:xsd:head.001.001.02'"/>
    <xsl:param name="Current_DateTime" select="current-dateTime()"/>

    <xsl:template match="/">
        <xsl:element name="BizMsgEnv" namespace="{$BAH_Namespace}">
            <!-- AppHdr logic same as pacs.008 -->
            <xsl:element name="Document" namespace="{$Target_Namespace}">
                <xsl:element name="PmtRtr" namespace="{$Target_Namespace}">
                    <xsl:element name="GrpHdr" namespace="{$Target_Namespace}">
                        <xsl:element name="MsgId" namespace="{$Target_Namespace}"><xsl:value-of select="//mt:Field20"/></xsl:element>
                        <xsl:element name="CreDtTm" namespace="{$Target_Namespace}"><xsl:value-of select="format-dateTime($Current_DateTime, '[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]Z')"/></xsl:element>
                    </xsl:element>
                    <xsl:element name="TxInf" namespace="{$Target_Namespace}">
                        <xsl:element name="RtrId" namespace="{$Target_Namespace}"><xsl:value-of select="//mt:Field20"/></xsl:element>
                        <xsl:element name="OrgnlEndToEndId" namespace="{$Target_Namespace}"><xsl:value-of select="//mt:Field21"/></xsl:element>
                        <xsl:element name="RtrdIntrBkSttlmAmt" namespace="{$Target_Namespace}">
                            <xsl:attribute name="Ccy" select="//mt:Field32A/mt:currency"/>
                            <xsl:value-of select="translate(//mt:Field32A/mt:amount, ',', '.')"/>
                        </xsl:element>
                        <xsl:element name="RtrRsnInf" namespace="{$Target_Namespace}">
                            <xsl:element name="Rsn" namespace="{$Target_Namespace}">
                                <xsl:element name="Cd" namespace="{$Target_Namespace}">AC04</xsl:element> <!-- Sample Reason: Closed Account -->
                            </xsl:element>
                        </xsl:element>
                    </xsl:element>
                </xsl:element>
            </xsl:element>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
