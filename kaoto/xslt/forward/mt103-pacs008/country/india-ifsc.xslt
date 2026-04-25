<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:template match="@*|node()"><xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy></xsl:template>

  <!-- India IFSC Logic: Detect RAW_ACCT://IF hook and map to INIF System -->
  <xsl:template match="p8:FinInstnId[contains(p8:pacs008_ns, 'RAW_ACCT://IF') or contains(text(), 'RAW_ACCT://IF')]">
    <xsl:copy>
      <xsl:apply-templates select="p8:BICFI"/>
      <xsl:element name="ClrSysMmbId" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
        <xsl:element name="ClrSysId" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
             <xsl:element name="Cd" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">INIF</xsl:element>
        </xsl:element>
        <xsl:element name="MmbId" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
            <xsl:value-of select="substring-after(., 'RAW_ACCT://IF')"/>
        </xsl:element>
      </xsl:element>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
