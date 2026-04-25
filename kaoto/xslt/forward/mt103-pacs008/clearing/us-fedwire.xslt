<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <!-- Identity Template -->
  <xsl:template match="@*|node()"><xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy></xsl:template>

  <!-- US Fedwire Logic: Detect RAW_ACCT://FW hook and map to formal Clearing System ID -->
  <xsl:template match="p8:FinInstnId[contains(p8:pacs008_ns, 'RAW_ACCT://FW') or contains(text(), 'RAW_ACCT://FW')]">
    <xsl:copy>
      <xsl:apply-templates select="p8:BICFI"/>
      <xsl:element name="ClrSysMmbId" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
        <xsl:element name="ClrSysId" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
             <xsl:element name="Cd" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">USFW</xsl:element>
        </xsl:element>
        <xsl:element name="MmbId" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
            <xsl:value-of select="substring-after(., 'RAW_ACCT://FW')"/>
        </xsl:element>
      </xsl:element>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
