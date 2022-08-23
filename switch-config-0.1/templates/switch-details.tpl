<p class="location">
 / <a href="/">noc</a> / <!-- TMPL_VAR NAME=SWITCH -->
</p>
<h2>Switch connections</h2>
<div>
 <img src="images/<!-- TMPL_VAR NAME=SWITCH -->.png" alt="Graphical switch connections" />
</div>
<h2>Port configuration</h2>
<table class="std">
 <tr class="top">
  <th>Port</th>
  <th>Label</th>
  <th>VLAN's</th>
 </tr>
<!-- TMPL_LOOP NAME=PORTS -->
<!-- TMPL_IF NAME="DISABLED" -->
 <tr class="disabled">
<!-- TMPL_ELSE -->
 <tr class="enabled">
<!-- /TMPL_IF -->
  <td class="portno"><!-- TMPL_VAR NAME=PORT --></td>
  <td><!-- TMPL_IF NAME="SWITCH" --><a href="<!-- TMPL_VAR NAME=SWITCH -->.html"><!-- TMPL_VAR NAME=SWITCH --></a>:<!-- TMPL_VAR NAME=PORTNUM --><!-- TMPL_ELSE --><!-- TMPL_VAR NAME=LABEL --><!-- /TMPL_IF --></td>
  <td><!-- TMPL_VAR NAME=VLAN --></td>
 </tr>
<!-- /TMPL_LOOP -->
</table>
<h2>VLAN configuration</h2>
<table class="std">
 <tr class="top">
  <th>VLAN</th>
  <th>Label</th>
  <th>Ports</th>
 </tr>
<!-- TMPL_LOOP NAME=VLANS -->
 <tr class="enabled">
  <td class="portno"><!-- TMPL_VAR NAME=ID --></td>
  <td><!-- TMPL_VAR NAME=LABEL --></td>
  <td><!-- TMPL_VAR NAME=PORTS --></td>
 </tr>
<!-- /TMPL_LOOP -->
</table>
