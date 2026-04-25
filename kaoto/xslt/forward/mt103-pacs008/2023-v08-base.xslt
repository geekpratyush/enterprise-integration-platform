<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:mt="http://www.prowidesoftware.com/pw-swift-core/mt"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08"
    xmlns:head="urn:iso:std:iso:20022:tech:xsd:head.001.001.02"
    exclude-result-prefixes="mt">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
  
  <xsl:variable name="pacs008_ns" select="'urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08'"/>
  <xsl:variable name="bah_ns" select="'urn:iso:std:iso:20022:tech:xsd:head.001.001.02'"/>

  <xsl:template match="/">
    <BizMsgEnv xmlns="{$bah_ns}">
      <!-- Business Application Header -->
      <AppHdr xmlns="{$bah_ns}">
        <Fr><FIId><FinInstnId><BICFI><xsl:value-of select="//mt:Sender"/></BICFI></FinInstnId></FIId></Fr>
        <To><FIId><FinInstnId><BICFI><xsl:value-of select="//mt:Receiver"/></BICFI></FinInstnId></FIId></To>
        <BizMsgIdr><xsl:value-of select="//mt:Field20"/></BizMsgIdr>
        <MsgDefIdr>pacs.008.001.08</MsgDefIdr>
        <BizSvc>swift.cbprplus.02</BizSvc>
        <CreDt>2024-04-17T12:00:00Z</CreDt>
      </AppHdr>
      
      <!-- Document -->
      <Document xmlns="{$pacs008_ns}">
        <FIToFICstmrCdtTrf>
          <GrpHdr>
            <MsgId><xsl:value-of select="//mt:Field20"/></MsgId>
            <CreDtTm>2024-04-17T12:00:00Z</CreDtTm>
            <NbOfTxs>1</NbOfTxs>
            <SttlmInf><SttlmMtd>INDA</SttlmMtd></SttlmInf>
          </GrpHdr>
          
          <CdtTrfTxInf>
            <PmtId>
                <InstrId><xsl:value-of select="//mt:Field20"/></InstrId>
                <EndToEndId><xsl:value-of select="(//mt:Field21, 'NOTPROVIDED')[1]"/></EndToEndId>
                <UETR><xsl:value-of select="//mt:UETR"/></UETR>
            </PmtId>
            
            <IntrBkSttlmAmt Ccy="{//mt:Field32A/mt:currency}"><xsl:value-of select="translate(//mt:Field32A/mt:amount, ',', '.')"/></IntrBkSttlmAmt>
            <IntrBkSttlmDt>2024-04-17</IntrBkSttlmDt>

            <!-- Agent Mapping with Identification Logic -->
            <xsl:call-template name="map-agent-generic">
              <xsl:with-param name="name" select="'DbtrAgt'"/>
              <xsl:with-param name="field" select="//mt:Field52A | //mt:Field52D"/>
            </xsl:call-template>
            
            <xsl:call-template name="map-agent-generic">
              <xsl:with-param name="name" select="'IntrmyAgt1'"/>
              <xsl:with-param name="field" select="//mt:Field53A | //mt:Field53B"/>
            </xsl:call-template>

            <xsl:call-template name="map-agent-generic">
              <xsl:with-param name="name" select="'CdtrAgt'"/>
              <xsl:with-param name="field" select="//mt:Field57A | //mt:Field57D"/>
            </xsl:call-template>

            <!-- Debtor & Creditor -->
            <Dbtr>
                <Nm><xsl:value-of select="//mt:Field50K/mt:name | //mt:Field50A/mt:name"/></Nm>
            </Dbtr>
            <Cdtr>
                <Nm><xsl:value-of select="//mt:Field59/mt:name | //mt:Field59A/mt:name"/></Nm>
            </Cdtr>

            <!-- Remittance -->
            <xsl:if test="//mt:Field70">
              <RmtInf><Ustrd><xsl:value-of select="//mt:Field70"/></Ustrd></RmtInf>
            </xsl:if>

          </CdtTrfTxInf>
        </FIToFICstmrCdtTrf>
      </Document>
    </BizMsgEnv>
  </xsl:template>

  <!-- Generic Agent Template to support specialization hooks -->
  <xsl:template name="map-agent-generic">
    <xsl:param name="name"/>
    <xsl:param name="field"/>
    <xsl:if test="$field">
        <xsl:element name="{$name}" namespace="{$pacs008_ns}">
          <xsl:element name="FinInstnId" namespace="{$pacs008_ns}">
            <xsl:if test="$field/mt:BIC">
              <xsl:element name="BICFI" namespace="{$pacs008_ns}"><xsl:value-of select="$field/mt:BIC"/></xsl:element>
            </xsl:if>
            <!-- Here's the key: preserve the raw text for the specialization patch -->
            <xsl:if test="$field/mt:account">
               <xsl:text>RAW_ACCT:</xsl:text><xsl:value-of select="$field/mt:account"/>
            </xsl:if>
          </xsl:element>
        </xsl:element>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
