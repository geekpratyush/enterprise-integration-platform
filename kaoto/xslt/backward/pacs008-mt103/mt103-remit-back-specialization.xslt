<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">

  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Reverse REMIT Rule: Extract ISO Remittance info and pack into MT 77T -->
  <xsl:template match="text()[contains(., '{4:')]">
    <xsl:value-of select="."/>
    
    <!-- Identify if remittance information exists -->
    <xsl:variable name="rmt" select="//p8:RmtInf"/>
    <xsl:if test="$rmt">
      <xsl:text>:77T:</xsl:text>
      <!-- Unstructured Remittance -->
      <xsl:value-of select="substring(normalize-space($rmt/p8:Ustrd), 1, 9000)"/><!-- Truncated to MT limit -->
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
