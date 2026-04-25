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

  <!-- REMIT Rule: Use Structured Remittance if field 77T was present (passed in custom tag for patch) -->
  <!-- Note: The main transformer should extract 77T into a temporary element for this patch to consume -->
  <xsl:template match="p8:RmtInf">
    <xsl:copy>
      <xsl:apply-templates select="node()"/>
      <!-- Expansion Logic: If we have specific remittance details from Field 77T -->
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
