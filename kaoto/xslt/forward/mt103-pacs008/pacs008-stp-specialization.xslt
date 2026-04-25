<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- STP Rule: Force Service Level to G001 (Tracked Customer Credit Transfer) -->
  <xsl:template match="p8:PmtTpInf">
    <xsl:copy>
      <xsl:apply-templates select="node() except p8:SvcLvl"/>
      <xsl:element name="SvcLvl" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
        <xsl:element name="Cd" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">G001</xsl:element>
      </xsl:element>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
