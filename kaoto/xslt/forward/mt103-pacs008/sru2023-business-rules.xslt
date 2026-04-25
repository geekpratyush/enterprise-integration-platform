<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:head="urn:iso:std:iso:20022:tech:xsd:head.001.001.02">
  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
  <xsl:template match="@*|node()"><xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy></xsl:template>
  <xsl:template match="head:BizSvc">
    <xsl:element name="BizSvc" namespace="urn:iso:std:iso:20022:tech:xsd:head.001.001.02">swift.cbprplus.02</xsl:element>
  </xsl:template>
</xsl:stylesheet>
