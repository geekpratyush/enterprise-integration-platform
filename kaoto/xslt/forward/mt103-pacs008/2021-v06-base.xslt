<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs">

  <!-- ========================================================================
       Legacy 2021 Baseline: MT103 → pacs.008.001.06
       ======================================================================== -->

  <xsl:variable name="pacs008_ns" select="'urn:iso:std:iso:20022:tech:xsd:pacs.008.001.06'"/>
  <xsl:variable name="bah_ns" select="'urn:iso:std:iso:20022:tech:xsd:head.001.001.01'"/>

  <xsl:template match="/">
    <xsl:element name="AppHdr" namespace="{$bah_ns}">
        <!-- Minimal BAH for v06 -->
        <xsl:element name="MsgDefIdr" namespace="{$bah_ns}">pacs.008.001.06</xsl:element>
    </xsl:element>
    <xsl:element name="Document" namespace="{$pacs008_ns}">
        <xsl:element name="FIToFICstmrCdtTrf" namespace="{$pacs008_ns}">
           <!-- Transformation Logic mirror of v08 but with v06 structures -->
        </xsl:element>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
