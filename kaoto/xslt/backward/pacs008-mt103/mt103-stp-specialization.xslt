<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">

  <xsl:output method="text" encoding="UTF-8"/>

  <!-- Identity-like copy for Text content -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Rule: Detect G001 Service Level and inject STP indicator into Block 3 -->
  <xsl:template match="text()[contains(., '{2:')]">
    <xsl:value-of select="."/>
    <xsl:if test="//p8:PmtTpInf/p8:SvcLvl/p8:Cd = 'G001'">
      <xsl:text>{3:{119:STP}}</xsl:text>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
