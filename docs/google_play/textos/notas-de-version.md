# Notas de la versión 1.2.0

Play Console pide las notas **por idioma**, con un límite de **500 caracteres**
cada una. Se pueden pegar todas de golpe usando las etiquetas de abajo: en el
campo de notas, elige «Copiar de otro idioma → pegar» o pega el bloque completo
en la vista de código que ofrece la consola.

> Solo aparecen los idiomas para los que ya exista ficha. Si todavía no has
> creado los catorce, pega el bloque igualmente: Play ignora los que no
> reconoce, y luego los rellena al añadir cada ficha.

Lo importante de esta versión es el **arreglo**: en la 1.1.0, entrar en un grupo
por invitación fallaba para unas tres de cada cuatro personas. Va primero porque
es lo que más gente notó.

## Bloque completo para pegar

```xml
<es-ES>
• Arreglado: entrar en un grupo con código y PIN fallaba para la mayoría de la
  gente. Ya funciona.
• Quien administra un grupo puede quitar a alguien. Sus gastos se quedan y los
  saldos siguen cuadrando.
• Al borrar tu cuenta desaparecen también tu nombre y tu correo de los grupos en
  los que estabas.
</es-ES>
<en-US>
• Fixed: joining a group with a code and PIN failed for most people. It works
  now.
• Group admins can remove someone. Their expenses stay and the balances still
  add up.
• Deleting your account now also removes your name and email from the groups you
  were in.
</en-US>
<gl-ES>
• Arranxado: entrar nun grupo con código e PIN fallaba para a maioría da xente.
  Xa funciona.
• Quen administra un grupo pode quitar a alguén. Os seus gastos quedan e os
  saldos seguen cadrando.
• Ao borrar a túa conta desaparecen tamén o teu nome e o teu correo dos grupos
  nos que estabas.
</gl-ES>
<ca>
• Corregit: entrar en un grup amb codi i PIN fallava per a la majoria de la gent.
  Ja funciona.
• Qui administra un grup pot treure algú. Les seves despeses es queden i els
  saldos continuen quadrant.
• En esborrar el teu compte desapareixen també el teu nom i el teu correu dels
  grups on eres.
</ca>
<eu-ES>
• Konpondua: taldean kodearekin eta PINarekin sartzea gehienei huts egiten
  zitzaien. Orain badabil.
• Taldea kudeatzen duenak norbait kendu dezake. Haren gastuak gelditzen dira eta
  saldoek bat egiten jarraitzen dute.
• Kontua ezabatzean zure izena eta helbide elektronikoa ere desagertzen dira
  zeunden taldeetatik.
</eu-ES>
<fr-FR>
• Corrigé : rejoindre un groupe avec un code et un PIN échouait pour la plupart
  des gens. C'est réparé.
• Qui administre un groupe peut en retirer quelqu'un. Ses dépenses restent et les
  soldes restent justes.
• Supprimer votre compte efface aussi votre nom et votre e-mail des groupes où
  vous étiez.
</fr-FR>
<it-IT>
• Corretto: entrare in un gruppo con codice e PIN non funzionava per la maggior
  parte delle persone. Ora funziona.
• Chi amministra un gruppo può rimuovere qualcuno. Le sue spese restano e i saldi
  tornano.
• Eliminando il tuo account spariscono anche nome ed email dai gruppi in cui
  eri.
</it-IT>
<pt-PT>
• Corrigido: entrar num grupo com código e PIN falhava para a maioria das
  pessoas. Já funciona.
• Quem administra um grupo pode remover alguém. As despesas ficam e os saldos
  continuam a bater certo.
• Ao apagar a tua conta desaparecem também o teu nome e o teu email dos grupos
  onde estavas.
</pt-PT>
<de-DE>
• Behoben: einer Gruppe mit Code und PIN beizutreten scheiterte bei den meisten.
  Jetzt geht es.
• Wer eine Gruppe verwaltet, kann jemanden entfernen. Die Ausgaben bleiben und
  die Salden stimmen weiter.
• Beim Löschen deines Kontos verschwinden auch Name und E-Mail aus den Gruppen,
  in denen du warst.
</de-DE>
<el-GR>
• Διορθώθηκε: η είσοδος σε ομάδα με κωδικό και PIN αποτύγχανε για τους
  περισσότερους. Τώρα δουλεύει.
• Όποιος διαχειρίζεται μια ομάδα μπορεί να αφαιρέσει κάποιον. Τα έξοδά του
  μένουν και τα υπόλοιπα βγαίνουν.
• Διαγράφοντας τον λογαριασμό σου φεύγουν και το όνομα και το email σου από τις
  ομάδες.
</el-GR>
<ru-RU>
• Исправлено: вход в группу по коду и PIN не работал у большинства. Теперь
  работает.
• Администратор группы может удалить участника. Его расходы остаются, и балансы
  сходятся.
• При удалении аккаунта из групп исчезают также ваше имя и адрес почты.
</ru-RU>
<ar>
• تم الإصلاح: الانضمام إلى مجموعة برمز ورقم سري كان يفشل لمعظم الناس. يعمل الآن.
• من يدير المجموعة يمكنه إزالة أحد الأعضاء. تبقى مصروفاته وتظل الأرصدة متوازنة.
• حذف حسابك يحذف أيضًا اسمك وبريدك من المجموعات التي كنت فيها.
</ar>
<zh-CN>
• 已修复：用邀请码和 PIN 加入群组对大多数人失败的问题。现在可以正常加入了。
• 群组管理员可以移出成员。该成员的支出保留，余额依然对得上。
• 删除账号时，你的姓名和邮箱也会从所在群组中一并移除。
</zh-CN>
<ja-JP>
• 修正: コードと PIN でグループに参加できない不具合。ほとんどの人に起きていました。
• グループの管理者がメンバーを外せるようになりました。支出は残り、残高も合ったままです。
• アカウントを削除すると、参加していたグループから名前とメールアドレスも消えます。
</ja-JP>
```

## Para la primera versión de prueba interna

Si solo vas a hacer una prueba interna contigo mismo, no hace falta nada de
esto: con la línea del idioma por defecto sobra.

```
Arreglado el fallo que impedía entrar en un grupo por invitación. Quien
administra puede ahora quitar a alguien del grupo.
```

## Si en el futuro cambian

Las notas describen **lo que ve el usuario**, no lo que cambió por dentro. De
esta versión se han dejado fuera a propósito el endurecimiento de las reglas de
Firestore para que la expulsión se compruebe en el servidor, y la página pública
de eliminación de cuenta que exige Google Play. Están en el CHANGELOG y en las
notas de la GitHub Release.
