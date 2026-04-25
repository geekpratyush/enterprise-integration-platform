<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08"
    xmlns:head="urn:iso:std:iso:20022:tech:xsd:head.001.001.02"
    exclude-result-prefixes="p8 head">

  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:template match="/">
    <xsl:for-each select="//p8:FIToFICstmrCdtTrf/p8:CdtTrfTxInf">
      <!-- Logic: MX-to-MT CBPR+ Transformation -->
      <xsl:text>{1:F01SENDERBIXXXX0000000000}{2:I103RECEVRBIXXXXN}</xsl:text>
      <xsl:if test="p8:PmtId/p8:UETR">
        <xsl:text>{3:{121:</xsl:text><xsl:value-of select="p8:PmtId/p8:UETR"/><xsl:text>}}</xsl:text>
      </xsl:if>
      <xsl:text>{4:&#10;</xsl:text>
      
      <!-- :20: Message Reference -->
      <xsl:text>:20:</xsl:text><xsl:value-of select="substring(p8:PmtId/p8:InstrId, 1, 16)"/><xsl:text>&#10;</xsl:text>
      
      <!-- :23B: Bank Operation Code -->
      <xsl:text>:23B:CRED&#10;</xsl:text>

      <!-- :32A: Value Date / Currency / Amount -->
      <xsl:text>:32A:</xsl:text>
      <xsl:value-of select="substring(translate(p8:IntrBkSttlmDt, '-', ''), 3, 6)"/>
      <xsl:value-of select="p8:IntrBkSttlmAmt/@Ccy"/>
      <xsl:value-of select="translate(format-number(p8:IntrBkSttlmAmt, '#0.00'), '.', ',')"/><xsl:text>&#10;</xsl:text>

      <!-- Agent Mapping: 52, 53, 56, 57 -->
      <xsl:if test="p8:DbtrAgt/p8:FinInstnId/p8:BICFI">
        <xsl:text>:52A:</xsl:text><xsl:value-of select="p8:DbtrAgt/p8:FinInstnId/p8:BICFI"/><xsl:text>&#10;</xsl:text>
      </xsl:if>
      <xsl:if test="p8:IntrmyAgt1/p8:FinInstnId/p8:BICFI">
        <xsl:text>:53A:</xsl:text><xsl:value-of select="p8:IntrmyAgt1/p8:FinInstnId/p8:BICFI"/><xsl:text>&#10;</xsl:text>
      </xsl:if>
      <xsl:if test="p8:IntrmyAgt2/p8:FinInstnId/p8:BICFI">
        <xsl:text>:56A:</xsl:text><xsl:value-of select="p8:IntrmyAgt2/p8:FinInstnId/p8:BICFI"/><xsl:text>&#10;</xsl:text>
      </xsl:if>
      <xsl:if test="p8:CdtrAgt/p8:FinInstnId/p8:BICFI">
        <xsl:text>:57A:</xsl:text><xsl:value-of select="p8:CdtrAgt/p8:FinInstnId/p8:BICFI"/><xsl:text>&#10;</xsl:text>
      </xsl:if>

      <xsl:text>:50K:</xsl:text><xsl:value-of select="p8:Dbtr/p8:Nm"/><xsl:text>&#10;</xsl:text>
      <xsl:text>:59:</xsl:text><xsl:value-of select="p8:Cdtr/p8:Nm"/><xsl:text>&#10;</xsl:text>

      <!-- Remittance (Field 70) -->
      <xsl:if test="p8:RmtInf/p8:Ustrd">
        <xsl:text>:70:</xsl:text><xsl:value-of select="substring(p8:RmtInf/p8:Ustrd, 1, 140)"/><xsl:text>&#10;</xsl:text>
      </xsl:if>

      <xsl:text>:71A:SHA&#10;</xsl:text>

      <!-- Enrichment (Field 72) -->
      <xsl:text>:72:</xsl:text>
      <xsl:if test="p8:Purp/p8:Cd">
        <xsl:text>/PURP/</xsl:text><xsl:value-of select="p8:Purp/p8:Cd"/><xsl:text>&#10;</xsl:text>
      </xsl:if>
      
      <xsl:text>-}</xsl:text>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
