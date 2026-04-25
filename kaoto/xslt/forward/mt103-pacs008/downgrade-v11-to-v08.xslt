<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:p8_old="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.11"
    xmlns:head="urn:iso:std:iso:20022:tech:xsd:head.001.001.02">
  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
  <xsl:template match="@*|node()"><xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy></xsl:template>
  <xsl:template match="p8_old:*">
    <xsl:element name="{local-name()}" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>
  <xsl:template match="head:MsgDefIdr">
    <xsl:element name="MsgDefIdr" namespace="urn:iso:std:iso:20022:tech:xsd:head.001.001.02">pacs.008.001.08</xsl:element>
  </xsl:template>
</xsl:stylesheet>
